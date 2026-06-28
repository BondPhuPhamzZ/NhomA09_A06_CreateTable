# CẨM NANG VẤN ĐÁP BẢO VỆ ĐỒ ÁN CSDL NÂNG CAO

Tài liệu này tổng hợp toàn bộ các câu hỏi kinh điển mà giảng viên thường xoáy vào dựa trên Rubric của trường HUFLIT. Hãy đọc kỹ để hiểu tận gốc rễ đồ án!

---

## CHƯƠNG 1 & 2: PHÂN TÍCH VÀ THIẾT KẾ CSDL

### 1. Tại sao lại cần tách bảng `SDT_KHACHHANG` ra riêng thay vì để gộp vào bảng `KHACHHANG`?
**Trả lời:** Vì Số điện thoại là một thuộc tính đa trị (Một người có thể có 2-3 SĐT). Nếu để chung vào bảng `KHACHHANG`, em sẽ vi phạm Chuẩn 1NF (Mọi thuộc tính phải là đơn trị). Việc tách bảng giúp CSDL đạt chuẩn hóa và dễ dàng truy vấn SĐT sau này.

### 2. Chuẩn hóa 3NF là gì? Làm sao biết đồ án này đạt 3NF?
**Trả lời:** 
- 1NF: Không có thuộc tính đa trị (Em đã tách bảng SĐT).
- 2NF: Không có thuộc tính phụ thuộc một phần vào Khóa chính (Các bảng của em đều dùng Khóa chính đơn, ví dụ `MaKH`, nên tự động đạt 2NF).
- 3NF: Không có thuộc tính phụ thuộc bắc cầu (VD: Bảng `VE` có `MaCB`, em không hề lưu tên Máy bay hay ngày bay vào bảng vé vì nó đã nằm bên bảng `CHUYENBAY`. Như vậy xóa bỏ triệt để sự dư thừa dữ liệu).

### 3. Tại sao chọn Khóa chính của Bảng Khách hàng là IDENTITY (số tự tăng) thay vì VARCHAR tự gõ?
**Trả lời:** Vì Khách hàng mới tăng lên liên tục mỗi ngày, việc để CSDL tự sinh số nguyên (1, 2, 3...) giúp tăng tốc độ INSERT và tiết kiệm bộ nhớ RAM khi truy vấn (so với kiểu chuỗi VARCHAR).

---

## CHƯƠNG 3: LẬP TRÌNH CSDL (STORED PROCEDURE, TRIGGER, CURSOR)

### 4. Hãy phân biệt tham số OUTPUT trong SP và câu lệnh SELECT thông thường? (Câu hỏi Rubric Dạng 2)
**Trả lời:** 
- `SELECT` dùng để trả về một hoặc nhiều "bảng dữ liệu" chứa nhiều dòng nhiều cột. Phù hợp để hiển thị dữ liệu ra màn hình.
- `OUTPUT` dùng để trả về một "giá trị tính toán duy nhất" (VD: Tổng số tiền 5 triệu) gán thẳng vào một biến trong bộ nhớ. Phù hợp để lập trình viên sử dụng kết quả đó tính toán tiếp mà không cần đọc cả một bảng cồng kềnh.

### 5. Tại sao trong Dạng 3 (sp_TopKhachHangVip), em dùng Bảng tạm (`#TempTable`) thay vì Subquery lồng nhau?
**Trả lời:** Bảng tạm giúp chia nhỏ bài toán phức tạp thành các bước tính toán đơn giản. Thay vì nhét một cục Subquery khổng lồ gây chậm máy, em gom dữ liệu vào bảng tạm, sau đó thoải mái sử dụng lệnh `UPDATE` trực tiếp trên bảng tạm (để xếp loại Kim cương/Vàng/Bạc) trước khi trả về kết quả cuối cùng. Code dễ đọc và tốc độ nhanh hơn nhiều!

### 6. Khi nào thì nên dùng Cursor? Tại sao không dùng SET-based (Lệnh UPDATE thẳng)?
**Trả lời:** 
Trong đồ án này, Cursor được dùng ở `sp_DongBoTrangThaiChuyenBay`.
Lý do không dùng Lệnh UPDATE 1 phát ăn ngay là vì: Trạng thái của **mỗi chuyến bay** bị phụ thuộc vào giờ bay của riêng chuyến bay đó so với giờ hệ thống. Có chuyến thì đổi sang 'Đang bay', có chuyến thì đổi sang 'Đã hạ cánh'. Cursor giúp em "túm cổ" từng chuyến bay một ra để làm toán If-Else, điều mà lệnh SET-based thông thường không thể linh hoạt bằng.

### 7. Bí mật của Trigger: Bảng `inserted` và `deleted` là gì?
**Trả lời:** Đây là 2 bảng ảo (magic tables) do RAM tạo ra trong tích tắc khi Trigger chạy.
- Khi người ta INSERT vé mới, cái vé đó nằm trong giỏ `inserted`. Em mượn cái vé đó để qua bảng Máy bay trừ đi 1 ghế trống (`trg_DatVe`).
- Khi người ta UPDATE giá vé, giá vé cũ nằm trong giỏ `deleted`, giá vé mới nằm trong giỏ `inserted`. Em bốc cả 2 giá trị này ném vào bảng Lịch sử Log (`trg_LogCapNhatGiaVe`).

### 8. Lệnh BEGIN TRAN và ROLLBACK trong SP Dạng 5 để làm gì?
**Trả lời:** Đây gọi là giao dịch (Transaction). Khi mua vé, em phải thực hiện 2 việc: Thêm vé vào bảng VE và Trừ ghế ở bảng CHUYENBAY. Nếu lỡ làm xong bước 1 mà cúp điện chưa kịp làm bước 2, hệ thống sẽ bị sai lệch (khách có vé nhưng kho không trừ ghế). Lệnh `ROLLBACK` sẽ hủy ngay lập tức toàn bộ quá trình nếu phát hiện lỗi ở bất kỳ bước nào, giúp CSDL an toàn tuyệt đối.

### 9. Câu lệnh INSTEAD OF DELETE khác gì AFTER DELETE?
**Trả lời:** 
- `AFTER`: Hành động xóa đã diễn ra thành công (mất dữ liệu), Trigger mới chạy để dọn dẹp hậu quả.
- `INSTEAD OF`: Hành động xóa bị chặn đứng ngay trước khi diễn ra! Thay vì Xóa, Trigger của em lén sửa trạng thái chuyến bay thành "Đã hủy" (`trg_ChongXoaChuyenBay`). Nó bảo vệ dữ liệu không bị xóa mất gốc.

---
**Chúc bạn tự tin tỏa sáng tại buổi bảo vệ Đồ án!**
