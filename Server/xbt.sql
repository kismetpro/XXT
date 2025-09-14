SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for CourseInfo
-- ----------------------------
DROP TABLE IF EXISTS `CourseInfo`;
CREATE TABLE `CourseInfo` (
  `classId` bigint NOT NULL,
  `courseId` bigint NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `teacher` varchar(255) DEFAULT NULL,
  `icon` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  PRIMARY KEY (`classId`,`courseId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------
-- Table structure for SignInfo
-- ----------------------------
DROP TABLE IF EXISTS `SignInfo`;
CREATE TABLE `SignInfo` (
  `activeId` bigint NOT NULL,
  `startTime` bigint DEFAULT NULL,
  `endTime` bigint DEFAULT NULL,
  `signType` int DEFAULT NULL,
  `ifRefreshEwm` tinyint DEFAULT NULL,
  PRIMARY KEY (`activeId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------
-- Table structure for SignRecord
-- ----------------------------
DROP TABLE IF EXISTS `SignRecord`;
CREATE TABLE `SignRecord` (
  `uid` bigint NOT NULL,
  `activeId` bigint NOT NULL,
  `source` bigint NOT NULL COMMENT '>0(uid)-1(auto)',
  `signTime` bigint NOT NULL,
  PRIMARY KEY (`uid`,`activeId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------
-- Table structure for UserCourse
-- ----------------------------
DROP TABLE IF EXISTS `UserCourse`;
CREATE TABLE `UserCourse` (
  `uid` bigint NOT NULL,
  `classId` bigint NOT NULL,
  `courseId` bigint NOT NULL,
  `isSelected` tinyint NOT NULL,
  PRIMARY KEY (`uid`,`classId`,`courseId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------
-- Table structure for UserInfo
-- ----------------------------
DROP TABLE IF EXISTS `UserInfo`;
CREATE TABLE `UserInfo` (
  `uid` bigint NOT NULL COMMENT 'userId',
  `name` varchar(255) DEFAULT NULL,
  `mobile` varchar(255) DEFAULT NULL,
  `token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `avatar` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`uid`),
  UNIQUE KEY `mobile` (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------
-- Table structure for UserPerm
-- ----------------------------
DROP TABLE IF EXISTS `UserPerm`;
CREATE TABLE `UserPerm` (
  `mobile` bigint NOT NULL,
  `permission` tinyint DEFAULT NULL,
  PRIMARY KEY (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS = 1;
