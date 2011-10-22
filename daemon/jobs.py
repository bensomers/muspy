# -*- coding: utf-8 -*-
#
# Copyright © 2009-2011 Alexander Kojevnikov <alexander@kojevnikov.com>
#
# muspy is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# muspy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with muspy.  If not, see <http://www.gnu.org/licenses/>.

import logging
import re
import StringIO
from urllib2 import Request, urlopen

from PIL import Image

from app.cover import Cover
from app.models import *
import app.musicbrainz as mb
from app.tools import str_to_date
from daemon import tools


def process():
    """Work on pending jobs."""
    while True:
        try:
            job = Job.objects.select_related('user').order_by('id')[0]
        except IndexError:
            break

        if job.type == Job.ADD_ARTIST:
            if not add_artist(job.user, job.data):
                tools.sleep()
                continue
        elif job.type == Job.ADD_RELEASE_GROUPS:
            if not add_release_groups(job.data):
                tools.sleep()
                continue

        elif job.type == Job.GET_COVER:
            get_cover(job.data)

        job.delete()


def add_artist(user, search):
    tools.sleep()
    logging.info('[JOB] Searching for artist [%s] for user %d' % (search, user.id))
    found_artists, count = mb.search_artists(search, limit=2, offset=0)
    if found_artists is None:
        logging.warning('[ERR] MusicBrainz error while searching, retrying')
        return False

    only_one = len(found_artists) == 1
    first_is_exact = (len(found_artists) > 1 and
                      found_artists[0]['name'].lower() == search.lower() and
                      found_artists[1]['name'].lower() != search.lower())
    if only_one or first_is_exact:
        artist_data = found_artists[0]
        mbid = artist_data['id']

        # get_by_mbid() queries MB, must sleep.
        tools.sleep()
        logging.info('[JOB] Adding artist %s' % mbid)
        try:
            artist = Artist.get_by_mbid(mbid)
        except Artist.Blacklisted:
            logging.warning('[ERR] Artist %s is blacklisted artists, skipping' % mbid)
            return True
        if not artist:
            logging.warning('[ERR] Could not fetch artist %s, retrying' % mbid)
            return False
        UserArtist.add(user, artist)
    else:
        logging.info('[JOB] Could not identify artist by name, saving for later')
        UserSearch(user=user, search=search).save()

    return True

def add_release_groups(mbid):
    logging.info('[JOB] Fetching release groups for artist %s' % mbid)
    try:
        artist = Artist.objects.get(mbid=mbid)
    except Artist.DoesNotExist:
        logging.warning('[ERR] Cannot find by mbid, skipping' % mbid)
        return True

    LIMIT = 100
    offset = 0
    while True:
        tools.sleep()
        logging.info('[JOB] Fetching release groups at offset %d' % offset)
        release_groups = mb.get_release_groups(mbid, limit=LIMIT, offset=offset)
        if release_groups:
            with transaction.commit_on_success():
                for rg_data in release_groups:
                    # Ignoring releases without a release date or a type.
                    if rg_data.get('first-release-date') and rg_data.get('type'):
                        if ReleaseGroup.objects.filter(mbid=rg_data['id']).exists():
                            continue
                        release_group = ReleaseGroup(
                            artist=artist,
                            mbid=rg_data['id'],
                            name=rg_data['title'],
                            type=rg_data['type'],
                            date=str_to_date(rg_data['first-release-date']),
                            is_deleted=False)
                        release_group.save()
        if release_groups is None:
            logging.warning('[ERR] MusicBrainz error, retrying')
            continue
        if len(release_groups) < LIMIT:
            break
        offset += LIMIT

    return True

def get_cover(mbid):
    logging.info('[JOB] Trying to find a cover for %s' % mbid)
    tools.sleep()
    logging.info('[JOB] Get releases')
    releases = mb.get_releases(mbid, limit=100, offset=0)
    if releases is None:
        logging.warning('[ERR] Could not get releases, skipping')
        return
    releases = [r for r in releases if r.get('date')]

    # Order releases by date.
    def by_date(a, b):
        # Convert 2011 to 2011-99-99 and 2011-01 to 2011-01-99.
        d1, d2 = a['date'], b['date']
        while len(d1) < 10: d1 += '-99'
        while len(d2) < 10: d2 += '-99'
        return cmp(d1, d2)
    releases = sorted(releases, cmp=by_date)

    # We don't want to check all 100 releases.
    releases = [r['id'] for r in releases][:10]

    url = None
    for release in releases:
        tools.sleep()
        logging.info('[JOB] Checking release %s' % release)
        try:
            request = Request(
                'http://musicbrainz.org/release/' + release,
                headers = {'User-Agent': 'muspy/2.0'})
            response = urlopen(request)
            html = response.read()
        except:
            logging.warning('[ERR] Could not fetch the release page, skipping')
            continue

        # Parsing the release page
        pattern = r'<div class="cover-art">\s*<img src="(?P<url>[^"]+)"'
        match = re.search(pattern, html)
        if not match:
            logging.info('[JOB] No cover art, skipping')
            continue
        url = match.group('url')

        logging.info('[JOB] Downloading the cover')
        image = None
        try:
            request = Request(url, headers = {'User-Agent': 'muspy/2.0'})
            response = urlopen(request)
            image = response.read()
        except:
            logging.warning('[ERR] Could not download, skipping')
            continue

        logging.info('[JOB] Saving the cover')
        try:
            im = Image.open(StringIO.StringIO(image))
            im = im.resize((120, 120), Image.ANTIALIAS)
            f = StringIO.StringIO()
            im.save(f, 'JPEG', quality=95)
            image = f.getvalue()
            Cover(mbid, image)
            return
        except:
            logging.warning('[ERR] Could not save the cover, skipping')
            continue

    logging.warning('[ERR] Could not find a cover')