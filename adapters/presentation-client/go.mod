module github.com/axisvela/enterprise-autonomy/adapters/presentation-client/v3

go 1.25.0

replace github.com/axisvela/LIMENORA-open/sdk/go/v3 => ../../../LIMENORA-open/sdk/go

replace github.com/axisvela/eidovela-open/v3 => ../../../EIDOVELA-open

replace github.com/axisvela/nomivela-open/v3 => ../../../NOMIVELA-open

require (
	github.com/axisvela/LIMENORA-open/sdk/go/v3 v3.0.0
	github.com/axisvela/eidovela-open/v3 v3.0.0
	github.com/axisvela/nomivela-open/v3 v3.0.0
	github.com/jackc/pgx/v5 v5.11.0
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/sync v0.17.0 // indirect
	golang.org/x/text v0.29.0 // indirect
)
