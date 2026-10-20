# Hai người giành chỗ cuối: Vì sao cần cô lập?

## 1. Tình huống

Giả sử một khóa học chỉ còn **1 chỗ trống**, nhưng có hai người dùng là An và Bình cùng đăng ký gần như đồng thời.

Quy trình của mỗi người gồm hai bước:

1. Kiểm tra số chỗ còn lại:

   ```sql
   SELECT capacity
   FROM courses
   WHERE id = 2;
   ```

2. Nếu còn chỗ thì thêm bản ghi đăng ký:

   ```sql
   INSERT INTO registrations (user_id, course_id)
   VALUES (..., 2);
   ```

Nếu không có cơ chế cô lập hoặc khóa phù hợp, cả An và Bình đều có thể đọc được giá trị **còn 1 chỗ** trước khi một trong hai người hoàn tất việc đăng ký.

## 2. Race condition xảy ra như thế nào?

Một thứ tự thực thi có thể xảy ra như sau:

| Thời điểm | Phiên A - An | Phiên B - Bình |
|---|---|---|
| 1 | Đọc khóa học và thấy còn 1 chỗ | |
| 2 | | Đọc khóa học và cũng thấy còn 1 chỗ |
| 3 | Thêm đăng ký của An | |
| 4 | | Thêm đăng ký của Bình |
| 5 | Commit | Commit |

Kết quả là cả hai người đều được đăng ký, trong khi hệ thống chỉ còn một chỗ. Số lượng người đăng ký có thể trở thành **41/40**.

Đây là **race condition**: kết quả phụ thuộc vào thứ tự và thời điểm đan xen của các giao dịch đồng thời. Vấn đề không nằm ở việc mỗi giao dịch riêng lẻ sai, mà ở chỗ các giao dịch cùng đọc và cập nhật một dữ liệu dùng chung mà không được phối hợp.

## 3. Vì sao cần cô lập giao dịch?

Tính cô lập (**Isolation**) là một trong các thuộc tính ACID của giao dịch. Nó giúp các giao dịch đồng thời không nhìn thấy hoặc làm ảnh hưởng đến trạng thái trung gian của nhau theo cách gây sai lệch dữ liệu.

Trong trường hợp này, việc cô lập cần bảo đảm rằng:

- Một phiên đang xử lý chỗ cuối có thể kiểm tra và giữ quyền xử lý bản ghi đó.
- Phiên khác phải chờ cho đến khi phiên thứ nhất hoàn tất.
- Sau khi được đánh thức, phiên thứ hai phải đọc lại dữ liệu mới nhất và nhận ra rằng không còn chỗ.

Nói cách khác, thao tác **kiểm tra còn chỗ** và **ghi nhận đăng ký** phải được thực hiện như một chuỗi thao tác nhất quán, không để hai phiên cùng vượt qua bước kiểm tra dựa trên cùng một giá trị cũ.

## 4. Cách xử lý bằng khóa dòng

Có thể dùng `SELECT ... FOR UPDATE` trong cùng một transaction để khóa dòng khóa học trong lúc xử lý:

```sql
BEGIN;

SELECT capacity
FROM courses
WHERE id = 2
FOR UPDATE;

-- Nếu capacity > 0 thì thêm đăng ký
INSERT INTO registrations (user_id, course_id)
VALUES (..., 2);

UPDATE courses
SET capacity = capacity - 1
WHERE id = 2;

COMMIT;
```

Khi An thực hiện `SELECT ... FOR UPDATE`, dòng dữ liệu của khóa học được khóa. Nếu Bình cũng thực hiện câu lệnh này, Bình sẽ phải chờ An `COMMIT` hoặc `ROLLBACK`.

Sau khi An hoàn tất, Bình đọc lại dữ liệu:

- Nếu không còn chỗ, Bình không được phép thêm đăng ký.
- Nếu giao dịch của An bị rollback, Bình có thể tiếp tục xử lý theo trạng thái được khôi phục.

## 5. Điều kiện quan trọng khi áp dụng

`SELECT ... FOR UPDATE` chỉ có tác dụng đúng khi các thao tác liên quan nằm trong **cùng một transaction**:

```sql
BEGIN;
SELECT ... FOR UPDATE;
INSERT ...;
COMMIT;
```

Không nên tách câu lệnh kiểm tra và câu lệnh thêm đăng ký thành hai transaction độc lập, vì khóa có thể được giải phóng trước khi thao tác `INSERT` diễn ra.

Ngoài khóa bi quan bằng `FOR UPDATE`, hệ thống cũng có thể dùng:

- **Cập nhật có điều kiện và kiểm tra số dòng bị ảnh hưởng:**

  ```sql
  UPDATE courses
  SET capacity = capacity - 1
  WHERE id = 2
    AND capacity > 0;
  ```

  Chỉ khi câu lệnh cập nhật thành công với một dòng bị ảnh hưởng thì mới thêm bản ghi đăng ký.

- **Ràng buộc cơ sở dữ liệu**, chẳng hạn unique constraint để ngăn một người đăng ký trùng cùng một khóa học.
- **Mức cô lập transaction phù hợp**, kết hợp với việc kiểm tra và cập nhật dữ liệu một cách nguyên tử.

## 6. Kết luận

Cần cô lập vì nhiều người dùng có thể thao tác đồng thời trên cùng một dữ liệu. Nếu chỉ đọc số chỗ còn lại rồi mới đăng ký mà không khóa hoặc không cập nhật nguyên tử, nhiều phiên có thể cùng thấy **“còn 1 chỗ”**, dẫn đến vượt quá sức chứa.

Giải pháp phổ biến là đặt thao tác trong một transaction và khóa dòng bằng `SELECT ... FOR UPDATE`, hoặc dùng một câu lệnh cập nhật có điều kiện. Nhờ đó, hệ thống bảo đảm chỉ một giao dịch được cấp chỗ cuối và dữ liệu không bị rơi vào trạng thái **41/40**.
