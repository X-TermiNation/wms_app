# Warehouse & Locations Module

Frontend prototype with GetX and in-memory dummy data.

## Features
- Warehouse list, add, edit, activate/deactivate and guarded delete.
- Warehouse-specific location list.
- Add/edit/delete storage locations.
- Location code generated as `ZONE-RACK-BIN`.
- Search and status filtering.
- Summary counts for Available, Occupied and Blocked.

## Route
`/warehouse`

## Notes
Data is currently held in RxLists and resets when the controller is recreated. Backend/API and persistence are intentionally deferred.
