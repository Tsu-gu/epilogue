package db

import (
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var db *gorm.DB

func GetDB() *gorm.DB {
	return db
}

func Connect() {
	mode := os.Getenv("MODE")
	var err error

	logger_ := logger.Warn
	if mode == "Release" {
		logger_ = logger.Silent
	}
	db, err = gorm.Open(postgres.Open("epilogue.db"), &gorm.Config{
		SkipDefaultTransaction: true,
		PrepareStmt:            true,
		Logger:                 logger.Default.LogMode(logger_),
	})
	if err != nil {
		panic("failed to connect database")
	}
}
