module github.com/axisrobo/enterprise-autonomy/adapters/presentation-client

go 1.25.0

replace github.com/axisvela/LIMENORA-open/sdk/go => ../../../LIMENORA-open/sdk/go

replace github.com/axisrobo/eidovela-open => ../../../EIDOVELA-open

replace github.com/axisrobo/nomivela-open/v2 => ../../../NOMIVELA-open

require (
	github.com/axisvela/LIMENORA-open/sdk/go v0.0.0-00010101000000-000000000000
	github.com/axisrobo/eidovela-open v0.0.0-00010101000000-000000000000
	github.com/axisrobo/nomivela-open/v2 v2.0.0-00010101000000-000000000000
	github.com/jackc/pgx/v5 v5.11.0
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/sync v0.17.0 // indirect
	golang.org/x/text v0.29.0 // indirect
)
