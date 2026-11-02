extends RefCounted
## Vòng lặp level: level hiển thị (s.level) tăng mãi, nội dung quay lại từ `loop_start` sau level cuối.
## Thuần, không đọc Config: bên gọi truyền số vào.


## Level nội dung (file data/levels) cho level hiển thị `display`.
## display <= last: giữ nguyên. Sau đó lặp [loop_start, last]; loop_start ngoài [1, last] thì kẹp lại.
static func content_level(display: int, loop_start: int, last: int) -> int:
	if display <= last or last < 1:
		return display
	var start := clampi(loop_start, 1, last)
	return start + (display - start) % (last - start + 1)
