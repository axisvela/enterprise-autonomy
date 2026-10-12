package main

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"strings"

	_ "github.com/jackc/pgx/v5/stdlib"
)

// ensureDatabases connects to the admin database of adminURL and creates each
// named database if absent. It lets the example run without psql/Docker.
func ensureDatabases(ctx context.Context, adminURL string, names []string) error {
	db, err := sql.Open("pgx", adminURL)
	if err != nil {
		return err
	}
	defer db.Close()
	for _, name := range names {
		if !validDBName(name) {
			return fmt.Errorf("invalid database name %q", name)
		}
		var exists bool
		if err := db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname=$1)`, name).Scan(&exists); err != nil {
			return err
		}
		if exists {
			continue
		}
		if _, err := db.ExecContext(ctx, `CREATE DATABASE `+quoteIdent(name)); err != nil {
			return fmt.Errorf("create database %s: %w", name, err)
		}
	}
	return nil
}

func validDBName(name string) bool {
	if name == "" {
		return false
	}
	for _, r := range name {
		if !(r == '_' || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')) {
			return false
		}
	}
	return true
}

func quoteIdent(name string) string { return `"` + strings.ReplaceAll(name, `"`, `""`) + `"` }

// withDatabase returns a copy of dsn with its path replaced by the named
// database, preserving the rest of the URL.
func withDatabase(dsn, name string) (string, error) {
	u, err := url.Parse(dsn)
	if err != nil {
		return "", err
	}
	u.Path = "/" + name
	return u.String(), nil
}
