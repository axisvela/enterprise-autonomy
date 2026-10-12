package main

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	_ "github.com/jackc/pgx/v5/stdlib"
)

// resetDatabases connects to the admin database of adminURL and drops then
// recreates each named database, so the example always starts from a clean
// schema. The product migrations are not uniformly idempotent (for example a
// re-run of the NOMIVELA migrations fails on the existing schema_migrations
// table), so a disposable reset is the reliable path for a local demo. It lets
// the example run without psql/Docker.
func resetDatabases(ctx context.Context, adminURL string, names []string) error {
	db, err := sql.Open("pgx", adminURL)
	if err != nil {
		return err
	}
	defer db.Close()
	for _, name := range names {
		if !validDBName(name) {
			return fmt.Errorf("invalid database name %q", name)
		}
		if _, err := db.ExecContext(ctx, `DROP DATABASE IF EXISTS `+quoteIdent(name)+` WITH (FORCE)`); err != nil {
			return fmt.Errorf("drop database %s: %w", name, err)
		}
		if _, err := db.ExecContext(ctx, `CREATE DATABASE `+quoteIdent(name)); err != nil {
			return fmt.Errorf("create database %s: %w", name, err)
		}
	}
	return nil
}

// ensureDatabaseSearchPath sets the default search_path for a database. EIDOVELA
// migrations 0007+ use unqualified table names and assume the connection
// search_path is eidovela,public; eidovela-migrate does not set it, so the
// example sets the database default before running the migration.
func ensureDatabaseSearchPath(ctx context.Context, adminURL, dbName, searchPath string) error {
	if !validDBName(dbName) {
		return fmt.Errorf("invalid database name %q", dbName)
	}
	db, err := sql.Open("pgx", adminURL)
	if err != nil {
		return err
	}
	defer db.Close()
	if _, err := db.ExecContext(ctx, `ALTER DATABASE `+quoteIdent(dbName)+` SET search_path TO `+searchPath); err != nil {
		return fmt.Errorf("set search_path on %s: %w", dbName, err)
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
