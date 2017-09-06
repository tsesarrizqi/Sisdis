Cara menjalankan server
	- Dari Linux terminal, masuk ke Erlang console dengan command berikut
		$ erl
	- Jalankan server (di dalam Erlang console)
		> server:start(8000).
	- Nilai 8000 dapat diganti dengan port lain

Cara mengcompile program (tidak diperlukan bila sudah ada file .beam)
	- Dari Linux terminal, masuk ke Erlang console dengan command berikut
		$ erl
	- Compile program (di dalam Erlang console)
		> compile:file(server).

Hal-hal yang telah dipelajari
	- Mengetahui bagaimana HTTP request/response terjadi di balik layar.
	- Mengenal komponen-komponen HTTP response/request (request/response statement, headers, body).
	- Mengetahui cara parsing HTTP untuk diolah.
	- Mengetahui cara memberikan respon sesuai hasil parsing.

Catatan:
	- penghitungan byte size untuk content-length untuk beberapa bagian juga termasuk karakter new line "\r\n" (bisa dilihat di source code)