extends GdUnitTestSuite


func test_whole_millions_read_as_m() -> void:
	assert_str(Num.text(3000000)).is_equal("3M")
	assert_str(Num.text(16000000)).is_equal("16M")


func test_a_million_that_is_not_whole_shows_one_decimal_cut_not_rounded() -> void:
	assert_str(Num.text(1500000)).is_equal("1.5M")
	assert_str(Num.text(1234567)).is_equal("1.2M")
	assert_str(Num.text(1999999)).is_equal("1.9M")
	assert_str(Num.text(1040000)).is_equal("1.0M")


func test_whole_thousands_read_as_k() -> void:
	assert_str(Num.text(1000)).is_equal("1K")
	assert_str(Num.text(40000)).is_equal("40K")
	assert_str(Num.text(500000)).is_equal("500K")


func test_other_numbers_under_a_million_get_dots_for_thousands() -> void:
	assert_str(Num.text(12345)).is_equal("12.345")
	assert_str(Num.text(1500)).is_equal("1.500")
	assert_str(Num.text(999999)).is_equal("999.999")
	assert_str(Num.text(999)).is_equal("999")
	assert_str(Num.text(0)).is_equal("0")


func test_the_sign_goes_in_front() -> void:
	assert_str(Num.text(-40000)).is_equal("-40K")
	assert_str(Num.text(-1234)).is_equal("-1.234")
	assert_str(Num.text(-1500000)).is_equal("-1.5M")
