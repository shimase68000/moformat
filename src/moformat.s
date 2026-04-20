***************************************************
*
*		MO Format
*
***************************************************

		.include	iocscall.mac
		.include	doscall.mac
		.include	scsi.mac

***************************************************

		.xref	data_block00
		.xref	data_block40
		.xref	ibm_ipl
		.xref	semi_ibm_ipl

***************************************************

MAX_BLOCK_SIZ	.equ	$7f
BLOCK_SIZE128	.equ	$03cbf8
BLOCK_SIZE230	.equ	$06cf74

*-----------------------------------------

*CLEAN_SIZ128	.equ	$26a	* 128MB Human68k/SHARP
*CLEAN_SIZ230	.equ	$27a	* 230MB Human68k/SHARP
CLEAN_SIZ128	.equ	$24a	* 128MB Human68k
CLEAN_SIZ230	.equ	$21a	* 230MB Human68k
CLEAN_SIZ128I	.equ	$207	* 128MB IBM format
CLEAN_SIZ230I	.equ	$1d5	* 230MB IBM format
CLEAN_SIZ128S	.equ	$11C	* 128MB	Semi-IBM format
CLEAN_SIZ230S	.equ	$108	* 230MB	Semi-IBM format

*-----------------------------------------
* exit code

EXITCODE_KEYSTOP	.equ	-1	* 強制終了
EXITCODE_NOMEMORY	.equ	-2	* メモリが足りない
EXITCODE_NOTUSE		.equ	-3	* ＳＣＳＩ使用不能
EXITCODE_NOTMO		.equ	-4	* ＭＯではない
EXITCODE_MEDIUM_ERR	.equ	-5	* 未対応のメディア
EXITCODE_WPROTECT	.equ	-6	* ライトプロテクト

***************************************************

		.offset	0	* offset for work

scsi_id		.ds.b	1	* -1
sw_reset	.ds.b	1	* 0
sw_disp		.ds.b	1	* 0
inquiry0	.ds.b	1
inquiry1	.ds.b	1
flag230		.ds.b	1	* bit0 0:128MB     1:230MB
				* bit1 0:Human68k  1:IBM
				* bit2 0:Normal    1:Semi ( See bit1='1' )
		.even
		
capacity0	.ds.l	1
capacity1	.ds.l	1
buffer_address	.ds.l	1
max_block_size	.ds.l	1
binary_date	.ds.l	1
binary_time	.ds.l	1

		.even

request_buf	.ds.b	16
modesense_buf	.ds.b	32
read_buffer	.ds.b	512

moformat_work_size:

***************************************************

		.text

* program start ----------------------

	bsr	print_title

	lea	moformat_work(pc),a6
	bsr	area_set
	bsr	get_para

* check parameter --------------------

	lea	moformat_work(pc),a6
	tst.b	sw_reset(a6)
	bne	scsi_reset

	move.b	scsi_id(a6),d4
	bmi	print_usage

* scsi check -------------------------

	and.l	#$f,d4
	bsr	scsi_testunit
	tst.l	d0
	bne	print_notuse

* medium check -----------------------

	bsr	scsi_inquiry

	move.b	inquiry0(a6),d0		* devide type = 0 or 7
	beq	1f
	cmp.b	#7,d0
	bne	print_notMO
1:
	move.b	inquiry1(a6),d0		* check removable bit
	bpl	print_notMO

* medium volume check ----------------

	bsr	scsi_readcap

	move.l	capacity0(a6),d0	* medium is 128MB or 230MB ?

	cmp.l	#BLOCK_SIZE128,d0
	bcs	print_medium_err	* medium is less than 121MB
	cmp.l	#BLOCK_SIZE230,d0
	bcs	1f
	bset	#0,flag230(a6)		* when 230MB medium then bit0 set.
1:
	cmp.l	#$200,capacity1(a6)	* 1sector = 512byte ?
	bne	print_medium_err

* formatter status check jump --------

	tst.b	sw_disp(a6)
	bne	format_status_check

* write protect check ----------------

	bsr	scsi_wprotect

* print medium volume ----------------

	lea	mes_medium128(pc),a5
	btst.b	#0,flag230(a6)
	beq	1f
	lea	mes_medium230(pc),a5
1:
	pea	(a5)
	DOS	_PRINT
	addq.l	#4,sp

	lea	mes_Human(pc),a5
	btst.b	#1,flag230(a6)
	beq	2f
	lea	mes_IBM(pc),a5
	btst.b	#2,flag230(a6)
	beq	2f
	lea	mes_SIBM(pc),a5
2:
	pea	(a5)
	DOS	_PRINT
	addq.l	#4,sp

* area check -------------------------

	bsr	area_check

* format stated message  -------------

*	lea	mes_table(pc),a1
	moveq	#0,d0
	move.b	flag230(a6),d0
	and.b	#%111,d0
	add.b	d0,d0
	move.w	mes_table(pc,d0.w),d0
	pea	mes_table(pc,d0.w)
	DOS	_PRINT
	addq.l	#4,sp

* clean medium  ----------------------

	bsr	m_clean			* pattern $00 clear

* write for medium ------------------ 

	btst.b	#1,flag230(a6)
	beq	m_write_Human68k
	btst.b	#2,flag230(a6)
	beq	m_write_ibm

*-----
m_write_semi_ibm:
	bsr	write_semi_ibm_ipl
	bra	exit_normally

*-----
m_write_ibm:
	bsr	write_ibm_ipl
	bra	exit_normally

*-----
m_write_Human68k:
	bsr	m_write_block00
	bsr	m_write_block40
	bsr	m_write_block42

exit_normally
	bsr	scsi_eject

	bsr	print_normalexit
	bsr	print_formatted

	DOS	_EXIT			* exit normally

*-----------------------------------------
mes_table
	.dc.w	mes_Human128-mes_table
	.dc.w	mes_Human230-mes_table
	.dc.w	mes_IBM128-mes_table
	.dc.w	mes_IBM230-mes_table
	.dc.w	mes_Human128-mes_table	* dummy
	.dc.w	mes_Human230-mes_table	* dummy
	.dc.w	mes_SIBM128-mes_table
	.dc.w	mes_SIBM230-mes_table

	.even

**************************************************
*	area set
**************************************************
area_set
	move.l	8(a0),d0	* end of memory
	move.l	a1,d1
	addq.l	#1,d1
	and.l	#$ffff_fffe,d1
	move.l	d1,buffer_address(a6)

	sub.l	d1,d0
	cmp.l	#512,d0
	bcs	print_nomemory
*	move.l	d0,free_area(a6)

	lsr.l	#8,d0
	lsr.l	d0		* d0/512
	cmp.l	#MAX_BLOCK_SIZ+1,d0
	bcs	1f
	move.l	#MAX_BLOCK_SIZ,d0
1:
	move.l	d0,max_block_size(a6)

	rts

**************************************************
*	medium clean ( pattern $00 )
**************************************************
m_clean
	move.l	buffer_address(a6),a1
	move.l	max_block_size(a6),d0
	subq.w	#1,d0
1:
	move.w	#512/32-1,d1
2:
	clr.l	(a1)+
	clr.l	(a1)+
	clr.l	(a1)+
	clr.l	(a1)+
	clr.l	(a1)+
	clr.l	(a1)+
	clr.l	(a1)+
	clr.l	(a1)+

	dbra	d1,2b
	dbra	d0,1b

	move.b	scsi_id(a6),d4
	and.l	#$f,d4

	move.l	buffer_address(a6),a1	* pointer of write data
	moveq	#0,d2			* start block no.

	moveq	#0,d7
	move.b	flag230(a6),d7
	add.w	d7,d7
	move.w	clean_size(pc,d7.w),d7

	bsr	write_nblock

	rts

*-------------------------------------------------
clean_size
	.dc.w	CLEAN_SIZ128
	.dc.w	CLEAN_SIZ230
	.dc.w	CLEAN_SIZ128I
	.dc.w	CLEAN_SIZ230I
	.dc.w	CLEAN_SIZ128		* dummy
	.dc.w	CLEAN_SIZ230		* dummy
	.dc.w	CLEAN_SIZ128S
	.dc.w	CLEAN_SIZ230S

	.even

**************************************************
*	medium write block $00-1f
**************************************************
m_write_block00

	move.b	scsi_id(a6),d4
	and.l	#$f,d4

	lea	data_block00(pc),a1

	bsr	marking_moformat_human68k	* moformat marking

	btst.b	#0,flag230(a6)
	beq	1f
	move.l	block00_230(pc),$0a(a1)	* 230MB specified
	lea	block04_230(pc),a2
	move.l	(a2)+,$804(a1)
	move.l	(a2),$808(a1)
	move.l	(a2),$80c(a1)
	move.l	(a2),$908(a1)
	move.l	(a2)+,$90c(a1)
	move.b	(a2)+,$81d(a1)
	move.b	(a2)+,$81e(a1)
1:
	move.l	#0,d2			* start block no.
	move.l	#$20,d3			* number of write block
	bsr	write_block

	rts

**************************************************
*	medium write block $40-41
**************************************************
m_write_block40

	move.b	scsi_id(a6),d4
	and.l	#$f,d4

	lea	data_block40(pc),a1
	btst.b	#0,flag230(a6)
	beq	1f
	lea	block40_230(pc),a5	* 230MB specified
	move.b	(a5)+,$14(a1)
	move.b	(a5)+,$1d(a1)
	move.b	(a5)+,$1f(a1)
	move.b	(a5)+,$20(a1)
1:
	move.l	#$40,d2			* start block no.
	move.l	#2,d3			* number of write block
	bsr	write_block

	rts

**************************************************
*	medium write block $42..
**************************************************
m_write_block42

	move.b	scsi_id(a6),d4
	and.l	#$f,d4

	move.l	buffer_address(a6),a1
	move.l	#$f6ffffff,(a1)		* FAT data

	move.l	#$42,d2			* start block no.
	move.l	#1,d3			* number of write block
	bsr	write_block

	move.l	#$136,d2
	btst.b	#0,flag230(a6)
	beq	1f
	move.l	#$11e,d2		* 230MB specified
1:
	move.l	#1,d3			* number of write block
	bsr	write_block

	rts

**************************************************
*	write ibm ipl
**************************************************
write_ibm_ipl
	move.b	scsi_id(a6),d4
	and.l	#$f,d4

	lea	ibm_ipl(pc),a1

	bsr	make_serial_number	* marking volume serial number
	move.b	d0,$27(a1)
	lsr.l	#8,d0
	move.b	d0,$28(a1)
	lsr.l	#8,d0
	move.b	d0,$29(a1)
	lsr.l	#8,d0
	move.b	d0,$2a(a1)

	bsr	marking_moformat_ibm	* marking moformat for IBM format

	btst.b	#0,flag230(a6)
	beq	1f

	lea	ibm_ipl230(pc),a5
	move.b	(a5)+,$0d(a1)
	move.b	(a5)+,$16(a1)
	move.b	(a5)+,$18(a1)
	move.b	(a5)+,$20(a1)
	move.b	(a5)+,$21(a1)
	move.b	(a5)+,$22(a1)
1:
	move.l	#0,d2			* start block no.
	move.l	#1,d3			* number of write block
	bsr	write_block

	lea	(a1),a2
	move.l	buffer_address(a6),a1
	move.l	#$f0ffffff,(a1)

	moveq	#0,d2
	move.w	$0e(a2),d2		* 第1FAT sector
	ror.w	#8,d2

	move.l	#1,d3			* number of write block
	bsr	write_block

	moveq	#0,d0
	move.w	$16(a2),d0
	ror.w	#8,d0
	add.w	d0,d2			* 第2FAT sector

	move.l	#1,d3			* number of write block
	bsr	write_block

	rts

**************************************************
*	write Semi-ibm ipl
**************************************************
write_semi_ibm_ipl
	move.b	scsi_id(a6),d4
	and.l	#$f,d4

	lea	ibm_ipl(pc),a1
	lea	(a1),a2
	lea	semi_ibm_ipl(pc),a5
	move.w	#$23-1,d0		* header copy size ($23byte)
1:	
	move.b	(a5)+,(a2)+
	dbra	d0,1b

	bsr	make_serial_number	* marking volume serial number
	move.b	d0,$27(a1)
	lsr.l	#8,d0
	move.b	d0,$28(a1)
	lsr.l	#8,d0
	move.b	d0,$29(a1)
	lsr.l	#8,d0
	move.b	d0,$2a(a1)

	bsr	marking_moformat_ibm	* marking moformat for IBM format

	btst.b	#0,flag230(a6)
	beq	1f

	lea	sibm_ipl230(pc),a5
	move.b	(a5)+,$0d(a1)
	move.b	(a5)+,$0e(a1)
	move.b	(a5)+,$16(a1)
	move.b	(a5)+,$18(a1)
	move.b	(a5)+,$20(a1)
	move.b	(a5)+,$21(a1)
	move.b	(a5)+,$22(a1)
1:
	move.l	#0,d2			* start block no.
	move.l	#1,d3			* number of write block
	bsr	write_block

	lea	(a1),a2
	move.l	buffer_address(a6),a1
	move.l	#$f0ffffff,(a1)

	moveq	#0,d2
	move.w	$0e(a2),d2		* 第1FAT sector
	ror.w	#8,d2

	move.l	#1,d3			* number of write block
	bsr	write_block

	moveq	#0,d0
	move.w	$16(a2),d0
	ror.w	#8,d0
	add.w	d0,d2			* 第2FAT sector

	move.l	#1,d3			* number of write block
	bsr	write_block

	rts

**************************************************
*	make serial number (for IBM format)
**************************************************
make_serial_number

	IOCS	_DATEGET
	move.l	d0,d1
	IOCS	_DATEBIN
	and.l	#$0FFF_FFFF,d0
	move.l	d0,binary_date(a6)
	move.l	d0,d7

	IOCS	_TIMEGET
	move.l	d0,d1
	IOCS	_TIMEBIN
	and.l	#$00FF_FFFF,d0
	move.l	d0,binary_time(a6)
	move.l	d0,d6

	lsl.w	#8,d0
	or.w	d7,d0
	swap	d0
	swap	d7
	move.w	d7,d0
	lsr.l	#8,d6
	add.w	d6,d0		* d0; volume serial number

	rts

**************************************************
*	marking moformat (for Human68k)
**************************************************
marking_moformat_human68k
	lea	mes_title(pc),a5	* moformat marking
	lea	$10(a1),a4
1:
	move.b	(a5)+,d0
	cmp.b	#13,d0
	beq	2f
	move.b	d0,(a4)+
	bra	1b
2:
	bsr	make_serial_number
	move.l	binary_date(a6),$80(a1)		* moforamt unique
	move.l	binary_time(a6),$84(a1)
	
	rts

**************************************************
*	marking moformat (for IBM/Semi-IBM format)
**************************************************
marking_moformat_ibm
	lea	mes_ibm_rev(pc),a5	* formatter rev
	lea	$3(a1),a4
	move.w	#8-1,d0
1:
	move.b	(a5)+,(a4)+
	dbra	d0,1b

	lea	mes_title(pc),a5	* moformat marking
	lea	$100(a1),a4
1:
	move.b	(a5)+,d0
	cmp.b	#$20,d0
	bcs	2f
	move.b	d0,(a4)+
	bra	1b
2:
	move.l	binary_date(a6),$180(a1)	* moforamt unique
	move.l	binary_time(a6),$184(a1)

	rts

**************************************************
*	format status check
**************************************************
format_status_check
	lea	read_buffer(a6),a1
	moveq	#0,d2
	moveq	#1,d3
	bsr	read_block

	pea	fmes_crlf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	bsr	format_check_formattype
	bsr	print_check_formattype

	bsr	format_check_formattype
	bsr	format_check_serialnumber
	bsr	print_check_serialnumber

	pea	fmes_crlf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	bsr	format_check_formattype
	bsr	print_check_formatmarking

	bsr	format_check_formattype
	bsr	format_check_formattime
	bsr	print_check_formattime
	
	DOS	_EXIT

*--------------------------------------
format_check_formattime
	cmp.b	#1,d0
	bne	2f

	cmp.l	#'X68k',$10(a1)
	bne	format_check_formattime_exit
	cmp.l	#' MO ',$14(a1)
	bne	format_check_formattime_exit
	cmp.l	#'Form',$18(a1)
	bne	format_check_formattime_exit
	cmp.w	#'at',$1c(a1)
	bne	format_check_formattime_exit
	move.l	$80(a1),d1
	move.l	$84(a1),d2
	moveq	#0,d0
	rts
2:	
	cmp.b	#2,d0
	beq	3f
	cmp.b	#3,d0
	bne	format_check_formattime_exit
3:
	cmp.b	#'M',3(a1)
	bne	format_check_formattime_exit
	cmp.b	#'O',4(a1)
	bne	format_check_formattime_exit
	cmp.b	#'F',5(a1)
	bne	format_check_formattime_exit
	cmp.b	#'v',6(a1)
	bne	format_check_formattime_exit
	move.l	$180(a1),d1
	move.l	$184(a1),d2
	moveq	#0,d0
	rts

format_check_formattime_exit
	moveq	#-1,d0
	rts

*--------------------------------------
format_check_serialnumber
	cmp.b	#2,d0
	beq	1f
	cmp.b	#3,d0
	beq	1f
	moveq	#-1,d0
	rts
1:
	cmp.b	#$29,$26(a1)
	beq	2f
	moveq	#-2,d0
	rts
2:
	move.b	$2a(a1),d1
	lsl.l	#8,d1
	move.b	$29(a1),d1
	lsl.l	#8,d1
	move.b	$28(a1),d1
	lsl.l	#8,d1
	move.b	$27(a1),d1
	moveq	#0,d0
	rts

*--------------------------------------
format_check_formattype
	cmp.l	#'X68S',(a1)
	bne	1f
	cmp.l	#'CSI1',4(a1)
	bne	1f
	moveq	#1,d0
	rts
1:	
	cmp.b	#$EB,(a1)		* IBM format
	beq	4f
	moveq	#0,d0
	rts
4:
	moveq	#8,d0			* sector/clustor
	btst.b	#0,flag230(a6)
	beq	2f
	add.b	d0,d0
2:
	cmp.b	$0d(a1),d0		* compare sector/clustor
	bhi	3f
	moveq	#3,d0
	rts
3:
	moveq	#2,d0
	rts

*-------------------------------------------------
print_check_formatmarking
	cmp.b	#1,d0
	bcs	print_check_formatmarking_exit
	bne	print_check_formatmarking_ibm

	pea	fmes_frev(pc)
	DOS	_PRINT
	addq.l	#4,sp

	lea	$10(a1),a2
1:
	move.b	(a2)+,d1
	cmp.b	#$20,d1
	bcs	2f
	bsr	putc_sub
	bra	1b
2:
	pea	fmes_crlf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	rts

print_check_formatmarking_ibm
	pea	fmes_frev(pc)
	DOS	_PRINT
	addq.l	#4,sp

	lea	$3(a1),a2
	move.w	#8-1,d7
4:
	move.b	(a2)+,d1
	bsr	putc_sub
	dbra	d7,4b

	pea	fmes_crlf(pc)
	DOS	_PRINT
	addq.l	#4,sp

print_check_formatmarking_exit
	rts

*-------------------------------------------------
print_check_formattime
	tst.b	d0
	bpl	1f
	rts
1:
	pea	fmes_ftime1(pc)
	DOS	_PRINT
	addq.l	#4,sp

	and.l	#$0fff_ffff,d1
	or.l	#$1000_0000,d1
	lea	time_buf(pc),a1
	IOCS	_DATEASC
	tst.l	d0
	bmi	2f

	pea	time_buf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	move.b	#' ',d1
	bsr	putc_sub

	move.l	d2,d1
	and.l	#$00ff_ffff,d1
	lea	time_buf(pc),a1
	IOCS	_TIMEASC
	tst.l	d0
	bmi	2f

	pea	time_buf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	pea	fmes_crlf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	rts

2:
	pea	fmes_ftime_err(pc)
	DOS	_PRINT
	addq.l	#4,sp

	rts

*-------------------------------------------------
time_buf	.ds.b	11
		.even
*-------------------------------------------------
print_check_serialnumber
	cmp.b	#-1,d0
	bne	1f
	rts
1:
	cmp.b	#-2,d0
	bne	2f
	pea	fmes_novolumeno(pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts
2:
	pea	fmes_volumeno(pc)
	DOS	_PRINT
	addq.l	#4,sp

	move.l	d1,d7
	rol.l	#8,d7
	move.b	d7,d1
	bsr	puthex_sub
	rol.l	#8,d7
	move.b	d7,d1
	bsr	puthex_sub
	move.b	#'-',d1
	bsr	putc_sub
	rol.l	#8,d7
	move.b	d7,d1
	bsr	puthex_sub
	rol.l	#8,d7
	move.b	d7,d1
	bsr	puthex_sub

	pea	fmes_crlf(pc)
	DOS	_PRINT
	addq.l	#4,sp

	rts

*-------------------------------------------------
print_check_formattype
	move.w	d0,d7

	pea	fmes_formattype(pc)
	DOS	_PRINT
	addq.l	#4,sp

	lea	fmes_medium128(pc),a5
	btst.b	#0,flag230(a6)
	beq	1f
	lea	fmes_medium230(pc),a5
1:
	pea	(a5)
	DOS	_PRINT
	addq.l	#4,sp

	add.w	d7,d7
	move.w	fmes_table1(pc,d7.w),d7
	pea	fmes_table1(pc,d7.w)
	DOS	_PRINT
	addq.l	#4,sp

	rts
*-------------------------------------------------
fmes_table1	.dc.w	fmes_unknown-fmes_table1
		.dc.w	fmes_Human-fmes_table1
		.dc.w	fmes_IBM-fmes_table1
		.dc.w	fmes_SIBM-fmes_table1

fmes_unknown	.dc.b	'Unformat or Unknown Format',13,10,0
fmes_Human	.dc.b	'Human68k Format',13,10,0
fmes_IBM	.dc.b	'IBM Format',13,10,0
fmes_SIBM	.dc.b	'Semi-IBM Format',13,10,0

fmes_medium128	.dc.b	'128MB ',0
fmes_medium230	.dc.b	'230MB ',0

fmes_formattype	.dc.b	'    フォーマットタイプ：',0
fmes_volumeno	.dc.b	'ボリュームシリアル番号：',0
fmes_novolumeno	.dc.b	'ボリュームシリアル番号：無し',13,10,0
fmes_frev	.dc.b	'    フォーマッタマーク：',0
fmes_ftime1	.dc.b   '        ディスク作成日：',0

fmes_ftime_err	.dc.b	'データが不正です',13,10,0
fmes_crlf	.dc.b	13,10,0

		.even

**************************************************
*	area check
**************************************************
area_check
	lea	read_buffer(a6),a1
	moveq	#0,d2
	moveq	#1,d3
	bsr	read_block

	bsr	format_check_formattype
	lea	keyin_mes_sibm(pc),a5
	cmp.w	#3,d0
	beq	1f
	lea	keyin_mes_ibm(pc),a5
	cmp.w	#2,d0
	beq	1f
	lea	keyin_mes_def(pc),a5
	cmp.w	#0,d0
	beq	1f

	bsr	area_check1
	lea	keyin_mes_alg(pc),a5
	tst.w	d0
	beq	1f
	lea	keyin_mes_phy(pc),a5
1:
	pea	(a5)
	DOS	_PRINT
	addq.l	#4,sp

	bra	inkey_sub

* alg. area -----------------------

area_check1
	lea	read_buffer(a6),a1
	moveq	#4,d2
	moveq	#1,d3
	bsr	read_block

	cmp.l	#'X68K',(a1)
	beq	4f

	moveq	#-1,d0
	rts

*------------
4:
	moveq	#15-1,d7		*領域15マデ
	moveq	#0,d1
1:
	lea	16(a1),a1
	tst.b	(a1)
	beq	area_check1_exit

	lea	(a1),a2

	move.b	#'(',d1
	bsr	putc_sub

	move.b	#' ',d1
	move.b	#15+$30,d2
	sub.b	d7,d2			* 領域番号
	cmp.b	#$3a,d2
	bcs	3f
	move.b	#'1',d1
	sub.b	#10,d2
3:
	bsr	putc_sub
	move.b	d2,d1
	bsr	putc_sub

	move.b	#')',d1
	bsr	putc_sub

	pea	area_space(pc)
	DOS	_PRINT
	addq.l	#4,sp

	move.b	(a2)+,d1		* 領域名
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub
	move.b	(a2)+,d1
	bsr	putc_sub

	pea	area_space1(pc)
	DOS	_PRINT
	addq.l	#4,sp

	move.l	4(a2),d0
	lsr.l	#8,d0			* div 1024
	lsr.l	#2,d0

	bsr	hex2dec			* 領域容量

	pea	area_mbyte(pc)
	DOS	_PRINT
	addq.l	#4,sp

	lea	area_atr0(pc),a5
	move.b	(a2),d0
	beq	2f
	lea	area_atr1(pc),a5
	cmp.b	#1,d0
	beq	2f
	lea	area_atr2(pc),a5
2:
	pea	(a5)
	DOS	_PRINT
	addq.l	#4,sp

	dbra	d7,1b

area_check1_exit
	moveq	#0,d0
	rts

*-------------------------------------------------
putc_sub
	cmp.w	#$20,d1
	bhi	putc_sub1
	move.w	#' ',d1

*------

putc_sub1
	move.w	d1,-(sp)
	DOS	_PUTCHAR
	addq.l	#2,sp

	rts

*-------------------------------------------------
puthex_sub
	move.b	d1,d2
	and.w	#$f0,d1
	lsr.w	#4,d1
	move.b	hexa_table(pc,d1.w),d1
	bsr	putc_sub

	move.b	d2,d1
	and.w	#$f,d1
	move.b	hexa_table(pc,d1.w),d1
	bsr	putc_sub

	rts

*--------------
hexa_table
	.dc.b	'0123456789ABCDEF'
	.even
*-------------------------------------------------
hex2dec
	move.l	#100000,d1
	clr.b	d5
1:
	moveq	#$30-1,d2
2:
	addq.b	#1,d2
	sub.l	d1,d0
	bcc	2b
	add.l	d1,d0

	tst.b	d5
	bne	3f
	cmp.b	#$30,d2
	sne	d5
	bne	3f

	move.b	#' ',d2
3:
	movem.l	d0-d1,-(sp)
	move.w	d2,-(sp)
	DOS	_PUTCHAR
	addq.l	#2,sp
	movem.l	(sp)+,d0-d1

	moveq	#0,d3
	move.w	d1,d3
	clr.w	d1
	swap	d1
	divu	#10,d1
	move.w	d1,d4
	swap	d4
	clr.w	d1
	add.l	d1,d3
	divu	#10,d3
	move.w	d3,d4
	move.l	d4,d1
	bne	1b

	rts

**************************************************************
*	keyin sub
**************************************************************
inkey_sub
	DOS	_INKEY

	cmp.w	#'Y',d0
	beq	inkey_sub_exit
	cmp.w	#'y',d0
	beq	inkey_sub_exit

	cmp.w	#'N',d0
	beq	inkey_sub_stop
	cmp.w	#'n',d0
	beq	inkey_sub_stop

	bra	inkey_sub

*-------------------------------------
inkey_sub_exit
	move.w	d0,d1
	bsr	putc_sub
	move.w	#13,d1
	bsr	putc_sub1
	move.w	#10,d1
	bsr	putc_sub1

	clr.w	-(sp)
	DOS	_KFLUSH
	addq.l	#2,sp

	rts
*-------------------------------------
inkey_sub_stop
	move.w	d0,d1
	bsr	putc_sub
	move.w	#13,d1
	bsr	putc_sub1
	move.w	#10,d1
	bsr	putc_sub1

	clr.w	-(sp)
	DOS	_KFLUSH
	addq.l	#2,sp

	bra	print_keystop

*------------------------------------------
keyin_mes_alg	.dc.b	13,10
		.dc.b	'メディアはすでに論理フォーマットされています。',13,10
		.dc.b	'すべてのデータが削除されますがよろしいですか？ [y/n] ',0
keyin_mes_phy	.dc.b	13,10
		.dc.b	'メディアはすでに物理フォーマットされています。',13,10
		.dc.b	'論理フォーマットしてもよろしいですか？ [y/n] ',0
keyin_mes_ibm	.dc.b	'メディアはすでに IBM フォーマットされています。',13,10
		.dc.b	'すべてのデータが削除されますがよろしいですか？ [y/n] ',0
keyin_mes_sibm	.dc.b	'メディアはすでに Semi-IBM フォーマットされています。',13,10
		.dc.b	'すべてのデータが削除されますがよろしいですか？ [y/n] ',0
keyin_mes_def	.dc.b	'フォーマットを開始します。よろしいですか？ [y/n] ',0

area_space	.dc.b	'  '
area_space1	.dc.b	'  ',0
area_mbyte	.dc.b	' Ｍバイト   ',0
area_atr0	.dc.b	'自動起動',13,10,0
area_atr1	.dc.b	'使用不可',13,10,0
area_atr2	.dc.b	'使用可能',13,10,0

		.even

**************************************************
*	scsi reset rutine
**************************************************
scsi_reset
	bsr	print_scsireset
	bsr	reset_scsibus
	bsr	print_normalexit

	DOS	_EXIT

**************************************************
*	get para
**************************************************
get_para
	move.b	#-1,scsi_id(a6)		* clear scsi_id
	clr.b	sw_reset(a6)
	clr.b	sw_disp(a6)
	clr.b	flag230(a6)

	tst.b	(a2)+
	beq	print_usage

get_para_loop
	move.b	(a2)+,d0
	beq	get_para_exit
	cmp.b	#$20,d0
	ble	get_para_loop
	cmp.b	#'/',d0
	beq	get_para_switch
	cmp.b	#'-',d0
	beq	get_para_switch

	cmp.b	#$20,(a2)
	bhi	print_usage

	sub.b	#'0',d0
	bcs	print_usage
	cmp.b	#7,d0
	bhi	print_usage

	and.l	#$f,d0
	move.b	d0,scsi_id(a6)
	bra	get_para_loop

get_para_exit
	rts

*-------------------------------------------------
get_para_switch
	move.b	(a2)+,d0
	beq	print_usage

	cmp.b	#'R',d0
	beq	get_switch_reset
	cmp.b	#'r',d0
	beq	get_switch_reset

	cmp.b	#'I',d0
	beq	get_switch_ibm
	cmp.b	#'i',d0
	beq	get_switch_ibm

	cmp.b	#'S',d0
	beq	get_switch_semi_ibm
	cmp.b	#'s',d0
	beq	get_switch_semi_ibm

	cmp.b	#'H',d0
	beq	get_switch_human68k
	cmp.b	#'h',d0
	beq	get_switch_human68k

	cmp.b	#'D',d0
	beq	get_switch_display
	cmp.b	#'d',d0
	beq	get_switch_display

	cmp.b	#'?',d0
	beq	print_usage

	bra	print_usage

*-------------------------------------------------
get_switch_human68k
	move.b	#%000,flag230(a6)
	bra	get_para_loop

*-------------------------------------------------
get_switch_ibm
	move.b	#%010,flag230(a6)
	bra	get_para_loop

*-------------------------------------------------
get_switch_semi_ibm
	move.b	#%110,flag230(a6)
	bra	get_para_loop

*-------------------------------------------------
get_switch_display
	st	sw_disp(a6)
	bra	get_para_loop

*-------------------------------------------------
get_switch_reset
	st	sw_reset(a6)
	bra	get_para_loop

**************************************************
*	write n block	n = d7.l
**************************************************
write_nblock
	move.l	max_block_size(a6),d3
	cmp.l	d3,d7
	bhi	1f
	move.l	d7,d3
1:
	bsr	write_block
	add.l	d3,d2
	sub.l	d3,d7
	bhi	write_nblock
	rts

**************************************************
*	write block
**************************************************
write_block
	movem.l	d2-d4/a1,-(sp)
	moveq	#1,d5
	SCSI	_S_WRITE
	tst.l	d0
	bne	scsi_err
	movem.l	(sp)+,d2-d4/a1

	rts

**************************************************
*	read block
**************************************************
read_block
	movem.l	d2-d4/a1,-(sp)
	moveq	#1,d5
	SCSI	_S_READ
	tst.l	d0
	bne	scsi_err
	movem.l	(sp)+,d2-d4/a1

	rts

**************************************************
*	scsi bus reset
**************************************************
reset_scsibus
	SCSI	_S_RESET
	rts

**************************************************
*	scsi testunit
**************************************************
scsi_testunit
	moveq	#10,d2
scsi_testunit1
	SCSI	_S_TESTUNIT
	tst.l	d0
	beq	scsi_testunit_exit
	cmp.l	#2,d0
	dbne	d2,scsi_testunit1
scsi_testunit_exit
	rts

**************************************************
*	scsi inquiry
**************************************************
scsi_inquiry
	moveq	#2,d3
	lea	inquiry0(a6),a1
	SCSI	_S_INQUIRY
	tst.l	d0
	bne	scsi_err
	rts

**************************************************
*	scsi read capacity
**************************************************
scsi_readcap
	lea	capacity0(a6),a1
	SCSI	_S_READCAP
	tst.l	d0
	bne	scsi_err
	rts

**************************************************
*	scsi eject mo
**************************************************
scsi_eject
	moveq	#0,d3
	SCSI	_S_PAMEDIUM

	lea	request_buf(a6),a1
	moveq	#$10,d3
	SCSI	_S_REQUEST

	moveq	#2,d3
	SCSI	_S_STARTSTOP
	tst.l	d0
	beq	1f

	moveq	#0,d3
	SCSI	_S_EJECT6MO1
1:
	rts

**************************************************
*	check write protect
**************************************************
scsi_wprotect
	lea	modesense_buf(a6),a1
	moveq	#$3f,d2		* page
	moveq	#32,d3
	moveq	#1,d5		* scsi block cap.
	SCSI	_S_MODESENSE
	tst.l	d0
	bne	scsi_err

	tst.b	2(a1)
	bmi	1f
	rts
1:
	bsr	print_wprotect
	bsr	scsi_eject

	move.w	#EXITCODE_WPROTECT,-(sp)
	bra	print_exit2a

**************************************************
*	print message
**************************************************
print_title
	pea	mes_title(pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

*-------------------------------------------------
print_normalexit
	pea	mes_normalexit(pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

*-------------------------------------------------
print_formatted
	pea	mes_formatted(pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

*-------------------------------------------------
print_scsireset
	pea	mes_scsireset(pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

*-------------------------------------------------
print_wprotect
	pea	mes_wprotect(pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

*-------------------------------------------------
print_usage
	pea	mes_usage(pc)
	DOS	_PRINT
	DOS	_EXIT

*-------------------------------------------------
print_notuse
	move.w	#EXITCODE_NOTUSE,-(sp)
	pea	mes_notuse(pc)
	bra	print_exit2

*-------------------------------------------------
print_medium_err
	move.w	#EXITCODE_MEDIUM_ERR,-(sp)
	pea	mes_medium_err(pc)
	bra	print_exit2

*-------------------------------------------------
print_notMO
	move.w	#EXITCODE_NOTMO,-(sp)
	pea	mes_notMO(pc)
	bra	print_exit2

*-------------------------------------------------
print_nomemory
	move.w	#EXITCODE_NOMEMORY,-(sp)
	pea	mes_nomemory(pc)
	bra	print_exit2

*-------------------------------------------------
print_keystop
	move.w	#EXITCODE_KEYSTOP,-(sp)
	pea	mes_keystop(pc)
	bra	print_exit2

*-------------------------------------------------
scsi_err
	move.w	d0,-(sp)
	pea	mes_scsierr(pc)

print_exit2
	DOS	_PRINT
	addq.l	#4,sp

print_exit2a
	DOS	_EXIT2

**************************************************
		.data

mes_ibm_rev	.dc.b	'MOFv2.01'

mes_title	.dc.b	'X68k MO Format version 2.01 Copyright 1994,95 UG.',13,10,0
mes_usage	.dc.b	'usage: MOFORMAT [switch] scsiid',13,10
		.dc.b	'switch:  /H     Human68k フォーマット(default)',13,10
		.dc.b	'         /I     IBM フォーマット',13,10
		.dc.b	'         /S     Semi-IBM フォーマット',13,10
		.dc.b	'         /D     フォーマット情報表示',13,10
		.dc.b	'         /R     ＳＣＳＩバス初期化',13,10,0

mes_medium128	.dc.b	'光磁気ディスク（１２８ＭＢ）を ',0
mes_medium230	.dc.b	'光磁気ディスク（２３０ＭＢ）を ',0
mes_Human	.dc.b	'Human68k フォーマットします。',13,10,13,10,0
mes_IBM		.dc.b	'IBM フォーマットします。',13,10,13,10,0
mes_SIBM	.dc.b	'Semi-IBM フォーマットします。',13,10,13,10,0

mes_scsierr	.dc.b	'ＳＣＳＩコマンド実行中に異常が発生しました',13,10,0
mes_notMO	.dc.b	'指定のＳＣＳＩ装置は光磁気ディスクではありません',13,10,0
mes_notuse	.dc.b	'指定のＳＣＳＩ装置は使用不能です',13,10,0
mes_medium_err	.dc.b	'未対応のメディアです',13,10,0
mes_wprotect	.dc.b	'メディアが書き込み禁止です',13,10,0
mes_scsireset	.dc.b	'ＳＣＳＩバス初期化中．．．',13,10,0
mes_Human128	.dc.b	13,10,'128MB Human68k フォーマット中．．．',0
mes_IBM128	.dc.b	13,10,'128MB IBM フォーマット中．．．',0
mes_SIBM128	.dc.b	13,10,'128MB Semi-IBM フォーマット中．．．',0
mes_Human230	.dc.b	13,10,'230MB Human68k フォーマット中．．．',0
mes_IBM230	.dc.b	13,10,'230MB IBM フォーマット中．．．',0
mes_SIBM230	.dc.b	13,10,'230MB Semi-IBM フォーマット中．．．',0
mes_normalexit	.dc.b	'正常終了しました。',13,10,0
mes_formatted	.dc.b	13,10,'ＭＯを使用する場合はＯＳにメディアの入れ換えを再認識させてください。',13,10,0
mes_keystop	.dc.b	'処理を中断しました。',13,10,0
mes_nomemory	.dc.b	'メモリが足りません。',13,10,0

		.even
					* Human68k format parameter
block00_230	.dc.l	$06cf74
block04_230	.dc.l	$00036420
		.dc.l	$000367ba
		.dc.b	$03,$64
block40_230	.dc.b	$04,$6e,$03,$64

					* IBM format parameter
ibm_ipl230	.dc.b	$08
		.dc.b	$da
		.dc.b	$20
		.dc.b	$74,$cf,$06

sibm_ipl230	.dc.b	$10
		.dc.b	$08
		.dc.b	$70
		.dc.b	$20
		.dc.b	$70,$cf,$06

		.even

moformat_work	.ds.b	moformat_work_size

