extends RefCounted
## Coverage run only (tools/affected.sh --coverage, docs/TESTING.md "Chọn test theo thay đổi"): the instrumented
## copy of src/**/*.gd marks here every method it enters ("src/meta/wallet.gd:earn") and every object it creates
## ("src/ui/shop.gd:<new>"). tests/run_all.gd reads and clears the set after each test file.

static var hits: Dictionary = {}
