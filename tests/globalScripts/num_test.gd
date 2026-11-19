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


func test_billions_trillions_and_quadrillions_read_as_b_t_q_like_millions() -> void:
	assert_str(Num.text(3000000000)).is_equal("3B")
	assert_str(Num.text(16000000000)).is_equal("16B")
	assert_str(Num.text(4500000000)).is_equal("4.5B")
	assert_str(Num.text(1999999999)).is_equal("1.9B")
	assert_str(Num.text(12000000000000)).is_equal("12T")
	assert_str(Num.text(3100000000000000)).is_equal("3.1Q")
	assert_str(Num.text(-4500000000)).is_equal("-4.5B")


func test_just_under_a_billion_still_reads_in_millions() -> void:
	assert_str(Num.text(999999999)).is_equal("999.9M")


func test_past_a_thousand_quadrillion_q_keeps_counting() -> void:
	assert_str(Num.text(9223372036854775807)).is_equal("9223.3Q")
