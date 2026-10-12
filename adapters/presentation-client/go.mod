module github.com/axisrobo/enterprise-autonomy/adapters/presentation-client

go 1.25.0

replace github.com/axisrobo/LIMENORA-open/sdk/go => ../../../LIMENORA-open/backend/sdk/go

replace github.com/axisrobo/eidovela-open => ../../../EIDOVELA-open

replace github.com/axisrobo/nomivela-open/v2 => ../../../NOMIVELA-open

require (
	github.com/axisrobo/LIMENORA-open/sdk/go v0.0.0-00010101000000-000000000000
	github.com/axisrobo/eidovela-open v0.0.0-00010101000000-000000000000
)
