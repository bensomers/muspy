PRAGMA user_version=1;
PRAGMA journal_mode=WAL;

CREATE TABLE "app_artist" (
    "id" integer NOT NULL PRIMARY KEY,
    "mbid" varchar(36) NOT NULL UNIQUE,
    "name" varchar(512) NOT NULL,
    "sort_name" varchar(512) NOT NULL,
    "disambiguation" varchar(512) NOT NULL
);
CREATE TABLE "app_job" (
    "id" integer NOT NULL PRIMARY KEY,
    "user_id" integer REFERENCES "auth_user" ("id"),
    "type" integer NOT NULL,
    "data" text NOT NULL
);
CREATE TABLE "app_notification" (
    "id" integer NOT NULL PRIMARY KEY,
    "user_id" integer NOT NULL REFERENCES "auth_user" ("id"),
    "release_group_id" integer NOT NULL,
    UNIQUE ("user_id", "release_group_id")
);
CREATE TABLE "app_releasegroup" (
    "id" integer NOT NULL PRIMARY KEY,
    "artist_id" integer NOT NULL REFERENCES "app_artist" ("id"),
    "mbid" varchar(36) NOT NULL,
    "name" varchar(512) NOT NULL,
    "type" varchar(16) NOT NULL,
    "date" integer NOT NULL,
    "is_deleted" bool NOT NULL,
    UNIQUE ("artist_id", "mbid")
);
CREATE TABLE "app_star" (
    "id" integer NOT NULL PRIMARY KEY,
    "user_id" integer NOT NULL REFERENCES "auth_user" ("id"),
    "release_group_id" integer NOT NULL REFERENCES "app_releasegroup" ("id"),
    UNIQUE ("user_id", "release_group_id")
);
CREATE TABLE "app_userartist" (
    "id" integer NOT NULL PRIMARY KEY,
    "user_id" integer NOT NULL REFERENCES "auth_user" ("id"),
    "artist_id" integer NOT NULL REFERENCES "app_artist" ("id"),
    "date" datetime NOT NULL,
    UNIQUE ("user_id", "artist_id")
);
CREATE TABLE "app_userprofile" (
    "id" integer NOT NULL PRIMARY KEY,
    "user_id" integer NOT NULL UNIQUE REFERENCES "auth_user" ("id"),
    "notify" bool NOT NULL,
    "notify_album" bool NOT NULL,
    "notify_single" bool NOT NULL,
    "notify_ep" bool NOT NULL,
    "notify_live" bool NOT NULL,
    "notify_compilation" bool NOT NULL,
    "notify_remix" bool NOT NULL,
    "notify_other" bool NOT NULL,
    "email_activated" bool NOT NULL,
    "activation_code" varchar(16) NOT NULL,
    "reset_code" varchar(16) NOT NULL,
    "legacy_id" integer
);
CREATE TABLE "app_usersearch" (
    "id" integer NOT NULL PRIMARY KEY,
    "user_id" integer NOT NULL REFERENCES "auth_user" ("id"),
    "search" varchar(512) NOT NULL
);
CREATE TABLE "auth_user" (
    "id" integer NOT NULL PRIMARY KEY,
    "username" varchar(30) NOT NULL UNIQUE,
    "first_name" varchar(30) NOT NULL,
    "last_name" varchar(30) NOT NULL,
    "email" varchar(75) NOT NULL UNIQUE,
    "password" varchar(128) NOT NULL,
    "is_staff" bool NOT NULL,
    "is_active" bool NOT NULL,
    "is_superuser" bool NOT NULL,
    "last_login" datetime NOT NULL,
    "date_joined" datetime NOT NULL
);
CREATE TABLE "django_session" (
    "session_key" varchar(40) NOT NULL PRIMARY KEY,
    "session_data" text NOT NULL,
    "expire_date" datetime NOT NULL
);
CREATE TABLE "piston_nonce" (
    "id" integer NOT NULL PRIMARY KEY,
    "token_key" varchar(18) NOT NULL,
    "consumer_key" varchar(18) NOT NULL,
    "key" varchar(255) NOT NULL
);
CREATE TABLE "piston_resource" (
    "id" integer NOT NULL PRIMARY KEY,
    "name" varchar(255) NOT NULL,
    "url" text NOT NULL,
    "is_readonly" bool NOT NULL
);
CREATE TABLE "piston_consumer" (
    "id" integer NOT NULL PRIMARY KEY,
    "name" varchar(255) NOT NULL,
    "description" text NOT NULL,
    "key" varchar(18) NOT NULL,
    "secret" varchar(32) NOT NULL,
    "status" varchar(16) NOT NULL,
    "user_id" integer REFERENCES "auth_user" ("id")
);
CREATE TABLE "piston_token" (
    "id" integer NOT NULL PRIMARY KEY,
    "key" varchar(18) NOT NULL,
    "secret" varchar(32) NOT NULL,
    "token_type" integer NOT NULL,
    "timestamp" integer NOT NULL,
    "is_approved" bool NOT NULL,
    "user_id" integer REFERENCES "auth_user" ("id"),
    "consumer_id" integer NOT NULL REFERENCES "piston_consumer" ("id")
);
CREATE INDEX "app_artist_sort_name" ON "app_artist" ("sort_name");
CREATE INDEX "app_job_user_id" ON "app_job" ("user_id");
CREATE INDEX "app_notification_release_group_id" ON "app_notification" ("release_group_id");
CREATE INDEX "app_notification_user_id" ON "app_notification" ("user_id");
CREATE INDEX "app_releasegroup_artist_id" ON "app_releasegroup" ("artist_id");
CREATE INDEX "app_releasegroup_date" ON "app_releasegroup" ("date" DESC);
CREATE INDEX "app_releasegroup_mbid" ON "app_releasegroup" ("mbid");
CREATE INDEX "app_star_release_group_id" ON "app_star" ("release_group_id");
CREATE INDEX "app_star_user_id" ON "app_star" ("user_id");
CREATE INDEX "app_userartist_artist_id" ON "app_userartist" ("artist_id");
CREATE INDEX "app_userartist_user_id" ON "app_userartist" ("user_id");
CREATE INDEX "app_userprofile_activation_code" ON "app_userprofile" ("activation_code");
CREATE INDEX "app_userprofile_legacy_id" ON "app_userprofile" ("legacy_id");
CREATE INDEX "app_userprofile_reset_code" ON "app_userprofile" ("reset_code");
CREATE INDEX "app_usersearch_user_id" ON "app_usersearch" ("user_id");
CREATE INDEX "django_session_expire_date" ON "django_session" ("expire_date");
CREATE INDEX "piston_consumer_user_id" ON "piston_consumer" ("user_id");
CREATE INDEX "piston_token_user_id" ON "piston_token" ("user_id");
CREATE INDEX "piston_token_consumer_id" ON "piston_token" ("consumer_id");
