/*
 Navicat Premium Data Transfer

 Source Server         : VM-ubuntuxxx
 Source Server Type    : PostgreSQL
 Source Server Version : 150008 (150008)
 Source Host           : localhost:5432
 Source Catalog        : test1
 Source Schema         : public

 Target Server Type    : PostgreSQL
 Target Server Version : 150008 (150008)
 File Encoding         : 65001

 Date: 26/12/2024 23:39:44
*/


-- ----------------------------
-- Table structure for log
-- ----------------------------
DROP TABLE IF EXISTS "public"."log";
CREATE TABLE "public"."log" (
  "int_id" varchar(16) COLLATE "pg_catalog"."default" NOT NULL,
  "created" timestamp(6),
  "str" text COLLATE "pg_catalog"."default",
  "address" text COLLATE "pg_catalog"."default",
  "email" varchar(320) COLLATE "pg_catalog"."default"
)
;

-- ----------------------------
-- Table structure for message
-- ----------------------------
DROP TABLE IF EXISTS "public"."message";
CREATE TABLE "public"."message" (
  "id" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "int_id" varchar(16) COLLATE "pg_catalog"."default" NOT NULL,
  "created" timestamp(6) NOT NULL,
  "status" bool,
  "str" text COLLATE "pg_catalog"."default"
)
;

-- ----------------------------
-- Indexes structure for table log
-- ----------------------------
CREATE INDEX "log_email_idx" ON "public"."log" USING btree (
  "email" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Primary Key structure for table message
-- ----------------------------
ALTER TABLE "public"."message" ADD CONSTRAINT "message_pkey" PRIMARY KEY ("id");
