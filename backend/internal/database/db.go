package database

import (
	"database/sql"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func InitDB(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return nil, err
	}

	// Set connection pool parameters
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Verify connection
	if err := db.Ping(); err != nil {
		return nil, err
	}

	return db, nil
}
