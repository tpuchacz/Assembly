_code segment
assume  cs:_code, ds:_data, ss:_stack
	
start:	mov	ax,_stack
	mov	ss,ax
	call GetParameters ;Sprawdzanie parametrow przed przypisaniem adresu segmentu danych
	mov	ax,_data       ;Parametry sa przechowane pod adresem 0700:0080
	mov	ds,ax          ;DS po przypisaniu _data przyjmuje inny adres niz 700, co nie pozwala wydobyc parametry
	mov	sp,offset top
;-------------------------------------
;              MAIN
;-------------------------------------
Main PROC
	xor dx,dx
	xor cx,cx
	call SetDefaults ;Tutaj ustalamy wartosci na podstawie parametrow konsoli
	call File ;Otwiera plik i zapisuje jego zawartosc do text
	call CalculateNote ;Oblicza czas trwania nuty na podstawie tempa
	mov ax,3
	int 10h ;Czyszczenie ekranu
	lea si,filename
	lea dx,filename
	call WriteString
	call LoadRtttl
ReturnToOS: mov CurrentNote,0
	call ChangeBackground
	mov ax, 4c00h
	int 21h
Main ENDP
;-------------------------------------
;     Wczytywanie parametrow
;-------------------------------------		
GetParameters PROC
	xor cx,cx
	lea si, Parameters
	lea di, ds:[82h] ;Pod tym adresem pierwszy znak parametrow(pod 81 jest spacja)
	mov	cl, ds:[80h] ;Pod tym adresem ilosc znakow w parametrach
	sub cl,1 ;Ilosc znakow zawiera niepotrzebna spacje
ReadParamsChar:	
	mov	bl, [di]
	push ds
	mov	ax,_data  ;Trzeba tymczasowo przypisywac poprawny adres segmentu danych
	mov	ds,ax     ;Bo inaczej parametry beda zapisane pod niepoprawnym adresem
	mov [si], bl
	pop ds
	inc si
	inc di
	loop ReadParamsChar	
	ret
GetParameters ENDP
;-----------------------------------------------------
;   Ustawianie wartosci domyslnych z parametrow
;-----------------------------------------------------
SetDefaults PROC
	cmp Parameters,0
	je JumpToIncorrect
	lea si,Parameters
	mov al,[si]
;-----------------------------------------------------
;    Sprawdzanie czasu trwania z parametrów
;-----------------------------------------------------
CheckDefaultDuration:
	cmp al,'0'
	jb JumpToIncorrect
	cmp al,'9'
	ja JumpToIncorrect
	sub al,'0'
	mov defaultDuration,al  ;Pierwszy znak czasu trwania
	inc si
	mov al,[si]
	cmp al,' '    
	je DoubleCheck ;Jesli nie ma drugiego znaku przechodzimy dalej
	cmp al,'2'
	jb JumpToIncorrect
	cmp al,'6'    
	ja JumpToIncorrect ;Drugim znakiem moze byc tylko 2 lub 6 (bo 16 lub 32)
	mov bl,defaultDuration
	xor ax,ax
	xor bh,bh
    mov al,10
    mul bl     ;Jesli sa dwa znaki to pierwszy mnozymy *10 (liczba dziesiatek)
	mov bl,[si]
	sub bl,'0'
    add bx,ax  ;A potem dodajemy liczbe jednosci
	mov al,bl
	inc si
	mov defaultDuration,bl
DoubleCheck: mov ah,1
	jmp Checking
JumpToIncorrect: jmp IncorrectParameterFormat
Checking: cmp al,ah
	je CheckDefaultOctave
	shl ah,1         ;Czas trwania to potegi dwojki az do 32
	cmp ah,64        ;wiec przesuwajac jedynke w lewo sprawdzamy jego poprawnosc   
	je JumpToIncorrect
	jmp Checking
;-----------------------------------------------------
;    Sprawdzanie czy oktawa jest w zakresie 4-7
;-----------------------------------------------------
CheckDefaultOctave: inc si
	mov al,[si]
	cmp al,'4'
	jb JumpToIncorrect
	cmp al,'7'
	ja JumpToIncorrect
	sub al,'0'
	mov defaultOctave,al
	inc si
	mov al,[si]
	cmp al,' '
	je CheckDefaultTempo
	jmp IncorrectParameterFormat
;-----------------------------------------------------
;Sprawdzanie tempa, moga byc 3 cyfry, min. 25 max 900
;-----------------------------------------------------
CheckDefaultTempo: xor dx,dx
	inc si
	mov bh,[si]
	cmp bh,'1'
	jb JumpToIncorrect
	cmp bh,'9'
	ja JumpToIncorrect
	cmp bh,' '
	je JumpToIncorrect
	inc si
	mov bl,[si]
	cmp bl,'0'
	jb JumpToIncorrect
	cmp bl,'9'
	ja JumpToIncorrect
	inc si
	mov dl,[si]
	cmp dl,0
	je IncorrectParameterFormat
	cmp dl,' '
	je SetTempo
	inc si
SetTempo:xor dh,dh
	xor ax,ax ;325
	mov cx,1
	sub bl,'0'
	sub bh,'0'
	cmp dl,' '
	je TwoDigits 
	xor dh,dh
	mov al,100
	mul bh     ;ax = 300
	mov cx,ax  ;cx = 300
	xor bh,bh
	sub dl,'0'
	xor ax,ax
	mov al,10
	mul bl
	mov bx,ax   ;mnozymy bh*100, bl*10
	add cx,bx   ;dodajemy
	add cx,dx
	mov defaultTempo,cx
	jmp CheckFileName
TwoDigits:xor ax,ax
	mov al,10
	mul bh
	mov bh,ah
	add bl,al
	xor bh,bh
	mov defaultTempo,bx
;----------------------------------------------------------------------------------------------------------------------------------
;Sprawdzanie nazwy pliku. Musi byc zakonczona .txt (jesli jestesmy na znaku kropki to sprawdzamy czy t potem czy x potem t)
;----------------------------------------------------------------------------------------------------------------------------------
CheckFileName:lea di,filename
	xor ax,ax
ReadingFileName:
	inc si
	mov al,[si]
	cmp al,0
	je IncorrectParameterFormat
	mov [di],ax
	inc di
	cmp al,'.'
	jne ReadingFileName
	inc si
	mov al,[si]
	mov [di],al
	inc di
	cmp al,'t'
	jne IncorrectParameterFormat
	inc si
	mov al,[si]
	mov [di],al
	inc di
	cmp al,'x'
	jne IncorrectParameterFormat
	inc si
	mov al,[si]
	mov [di],al
	inc di
	cmp al,'t'
	jne IncorrectParameterFormat
	ret
IncorrectParameterFormat:lea dx, errorWrongParameters
	mov ah,9
	int 21h
	mov ax, 4c00h
	int 21h
SetDefaults ENDP
;-------------------------------------
;          Sekcja pliku
;-------------------------------------	
File PROC
	lea dx, filename
	mov al, 0
	mov ah, 3Dh ;Otwieranie pliku
	int 21h
	jc NotFound ;Jesli nie znaleziono to Carry Flag = 1
	mov filehandle, ax
	lea si, text
read_line:
	mov ah, 3Fh ;Czytanie z pliku
	mov bx, filehandle
	lea dx, char
	mov cx, 1
	int 21h
	cmp ax, 0  ;Sprawdzanie konca pliku
	je EO_file
	mov al, char
	mov [si], al
	inc si
	jmp read_line
EO_file:
    ret
NotFound:lea dx,errorFileNF
	mov ah,9h
	int 21h
	mov ax, 4c00h
	int 21h
FILE ENDP
;-----------------------------------------------------
;   Obliczanie czasu trwania nuty na podstawie tempa
;-----------------------------------------------------
CalculateNote PROC
    mov ax,60000d
    xor dx,dx
    div defaultTempo
    shl ax,2
    mov WholeNoteDuration,ax ;daje wynik dla d=4, aby zmienic na wyzsze trzeba przemnozyc
    ret
CalculateNote ENDP
;-------------------------------------
;          Sekcja muzyki
;-------------------------------------
LoadRtttl PROC
    lea si,text ;Wczytujemy kod rtttl
	mov bl,[si] ;Sprawdzamy pierwszy znak
	jmp CheckDuration2
CheckDuration: call PlaySong
CheckDuration2:
	cmp bl,'0'
	jb error     ;8
	cmp bl,'9' ;Narazie zakladam ze od 0-9
	jbe SetDuration
CheckNote:
    cmp CurrentNoteDuration,0
    je SetDefaultDuration
DefaultDurationSet:
	or bl,32 ;Zamienia duze na male litery, jesli male to zostaja
	cmp bl,'a'
	jb error  
	cmp bl,'p' ;Narazie tylko male litery
	jbe SetNote
;-------------------------------------
;              Error
;-------------------------------------	
error:lea dx,errorMsg
	MOV AH,09h
	INT 21h
	jmp ReturnToOS
;-------------------------------------
;   Ustalanie czasu trwania nuty
;-------------------------------------	
SetDefaultDuration:
    mov cl,DefaultDuration
    call Duration
    jmp DefaultDurationSet
Duration:
    mov ax,WholeNoteDuration
    mov CurrentNoteDuration,ax
    xor dx,dx
	div cx ;cx zawiera podana lub domyslna duration
	mov CurrentNoteDuration,ax
DurationWithDot:
	xor dx,dx
    mov bx,1000
    mul bx  
	mov CurrentNoteDurationHigh,dx
	mov CurrentNoteDurationHigh,dx
    mov bl,[si] ;Znak wraca
	ret
	
SetDuration:xor cx,cx
    sub bl,'0'   ;Jesli mamy 16 to w bl teraz kod 1
	mov al,'9'
	inc si       ;Jesli 16 to bierzemy 6 z 16
	cmp [si],al  ;Sprawdzenie czy faktycznie sa dwie cyfry Duration
	jbe SecondOne
	dec si       ;Jesli nie ma dwoch cyfr to wracamy z powrotem
AfterSecondOne: mov cl,bl   
	call Duration
	inc si
    mov bl,[si] ;c 
	jmp CheckNote
;------------------------------------------------------------------
;   Sprawdzenie czy duration sklada sie z dwoch znakow (16/32)
;------------------------------------------------------------------	
SecondOne:
    xor ax,ax
    mov al,10
    mul bl ;1*10 lub 3*10
	xor bl,bl;bl=0 bh=6 lub bh=2
	mov bl,[si]
	sub bl,'0'
    add bx,ax;ax=10 lub ax=30, bx=6 lub bx=2
	xor bh,bh
    jmp AfterSecondOne	
	
SetNote:
	mov CurrentNote,bl
	call Note
	inc si
	mov bl,[si]
	cmp bl,','
	je Przecinek
	cmp bl,0
	je Converted ;Jesli ostatnim znakiem jest 0 to plik sie skonczyl
	mov CurrentNoteDuration,0
	jmp CheckDuration
Converted: call PlaySong ;Odegranie ostatniej nuty
	ret ;Powrot do glownej czesci programu

Przecinek:
    inc si
    mov bl,[si]
	mov CurrentNoteDuration,0
    jmp CheckDuration
;------------------------------------------------
;   Ustalanie czestotliwosci na podstawie nuty
;------------------------------------------------
CisNote:
    inc si
    mov bl,[si]
    mov IsCis,1
    jmp GoBack	
DotAfterNote: call AddDuration
	jmp GoBack
	
Note: inc si
    mov bl,[si]
    cmp bl,'#'
    je CisNote
GoBack: cmp bl,'.'
	je DotAfterNote
	cmp CurrentNote,'p'
	je NoteP
	cmp CurrentNote,'c'
	je NoteC
	cmp CurrentNote,'d'
	je NoteD
	cmp CurrentNote,'e'
	je NoteE
	cmp CurrentNote,'f'
	je NoteF
	cmp CurrentNote,'g'
	je NoteG
	cmp CurrentNote,'a'
	je NoteA
	cmp CurrentNote,'b'
	je NoteB
noteP: mov ax,1
	jmp SetPause
noteB: mov ax,NoteB4Freq
	jmp Frequency
noteC: cmp IsCis,1
    je NoteCCis
    mov ax,NoteC4Freq
    jmp Frequency
NoteCcis: mov ax,NoteC4CisFreq
    mov IsCis,0 
    jmp Frequency
noteD: cmp IsCis,1
    je NoteDCis
    mov ax,NoteD4Freq
	jmp Frequency
NoteDcis: mov ax,NoteD4CisFreq
    mov IsCis,0 
    jmp Frequency
noteE: mov ax,NoteE4Freq
	jmp Frequency
noteF: cmp IsCis,1
    je NoteFCis
    mov ax,NoteF4Freq 
	jmp Frequency
NoteFcis: mov ax,NoteF4CisFreq
    mov IsCis,0 
    jmp Frequency
noteG: cmp IsCis,1
    je NoteGCis
    mov ax,NoteG4Freq
	jmp Frequency
NoteGcis: mov ax,NoteG4CisFreq
    mov IsCis,0 
    jmp Frequency
noteA: cmp IsCis,1
    je NoteACis 
    mov ax,NoteA4Freq
	jmp Frequency
NoteAcis: mov ax,NoteA4CisFreq
    mov IsCis,0 
Frequency:
    mov CurrentFreq,ax
    call SetOctave
    mov cl,CurrentOctave
    shr CurrentFreq,cl
	mov ax,CurrentFreq
SetPause: mov CurrentFreq,ax
    ret
;-------------------------------------------------------------------------
;   Ustalanie oktawy (zmiana czestotliwosci na odpowiadajaca oktawie)
;-------------------------------------------------------------------------	
SetOctave:
	cmp bl,','
	je SetDefaultOctave
	cmp bl,0
	je SetDefaultOctave
    sub bl,'0'+4  ;Bedzie potrzebne do przesuwania w prawo (Dzielenia przez 2)
	mov CurrentOctave,bl ;Sprawdzamy jaka oktawa	
	jmp OctaveInFile
SetDefaultOctave: mov bl,DefaultOctave
	mov CurrentOctave,bl
	sub CurrentOctave,4
OctaveInFile: ret
;------------------------------------------------
;       Przedluzenie czasu trwania nuty
;------------------------------------------------	
AddDuration:
	mov ax, CurrentNoteDuration
	shr ax,1
    add CurrentNoteDuration,ax
    mov ax, CurrentNoteDuration
    call DurationWithDot
    inc si
    mov bl,[si]
    ret
LoadRtttl ENDP
;------------------------------------------------
;            Granie melodii
;------------------------------------------------		
PlaySong PROC
	push si
	push bx
	mov cx,CurrentNoteDurationHigh
    mov dx,CurrentNoteDurationLow
	mov ax,CurrentFreq
	MOV BX,AX
	call ChangeBackground
	XOR AX,AX
    MOV AL, 182     
    OUT 43h, AL      
    MOV AX,BX
    OUT 42h, AL ;Nizszy bajt czestotliwosci      
    MOV AL,AH     
	OUT 42h,AL ;Wyzszy bajt czestotliwosci  
    IN AL, 61h  ;Wlaczenie glosnika  
    OR AL, 00000011b ;Wlaczenie transferu danych do glosnika
    OUT 61h, AL
    MOV AH, 86h ;Czekaj na czas trwania nuty
    INT 15h  
    IN AL, 61h  ;Wylaczenie glosnika
    AND AL, 11111100b    ;Wylaczenie transferu danych do glosnika  
    OUT 61h, AL   
	add si,6
	xor al,al
	pop bx
	pop si
	ret
PlaySong ENDP
;------------------------------------------------
;     Zmiana koloru tla na podstawie nuty
;------------------------------------------------	
ChangeBackground PROC
	PUSH CX
	PUSH SI
	MOV DI, 1 ;Poczatek segmentu ekranu
    MOV AX, 0B800h ;Segment danych ekranu
    MOV ES, AX
    MOV CX, 2000 ;Rozmiar ekranu
	XOR SI, SI
FillBackground: call ChangeColor
    MOV ES:[DI], AL ;Kolor heksadecymalnie zapisany do fragmentu ekranu
    ADD DI, 2 ;kolejny
	AND SI, 07h ;Modulo 8
    LOOP FillBackground
	POP SI
	POP CX
	ret	
ChangeColor:
	cmp CurrentNote,0
	je SetDefaultBackground
	cmp CurrentNote,'p'
	je ColorNoteP
	cmp CurrentNote,'c'
	je ColorNoteC
	cmp CurrentNote,'d'
	je ColorNoteD
	cmp CurrentNote,'e'
	je ColorNoteE
	cmp CurrentNote,'f'
	je ColorNoteF
	cmp CurrentNote,'g'
	je ColorNoteG
	cmp CurrentNote,'a'
	je ColorNoteA
	cmp CurrentNote,'b'
	je ColorNoteB
	ret
ColorNoteP: mov al,[fColors]
	jmp ColorSet
ColorNoteC: mov al,[fColors+1]
	jmp ColorSet
ColorNoteD: mov al,[fColors+2]
	jmp ColorSet
ColorNoteE: mov al,[fColors+3]
	jmp ColorSet
ColorNoteF: mov al,[fColors+4]
	jmp ColorSet
ColorNoteG: mov al,[fColors+5]
	jmp ColorSet
ColorNoteA: mov al,[fColors+6]
	jmp ColorSet
ColorNoteB: mov al,[fColors+7]
	jmp ColorSet
SetDefaultBackground: mov al,07h
ColorSet: ret
ChangeBackground ENDP
;-------------------------------------
;     Dodawanie $ na koncu stringa
;-------------------------------------		
WriteString PROC
	mov al,[si]
CheckForZero:inc si
	mov al,[si]
	cmp al,0
	jne CheckForZero
	mov ah,'$'
	mov [si],ah
	MOV AX,0900h
	INT 21h
	mov ah,0
	mov [si],ah
	dec si
	mov [si],ah
	ret
WriteString ENDP
_code ends

_data segment
	Parameters db 255 dup(0)
	errorMsg db "Niepoprawny format RTTTL w pliku!",'$'
	errorFileNF db "Nie znaleziono podanego pliku!",'$'
	errorWrongParameters db "Niepoprawne parametry!",10,13,"Poprawna forma to: Czas_trwania Oktawa Tempo Nazwa_pliku.txt"
	errorWrongParameters2 db 10,13,"Dostepny czas trwania to: 1,2,4,8,16,32",10,13
	errorWrongParameters3 db "Dostepne oktawy to: 4,5,6,7",10,13,"Dostepne tempo z zakresu: 25 do 900",'$'
	filename	db 255 dup(0)
	char		db ?
	filehandle	dw ?
	text		db 9999 dup(0)
	DefaultDuration db 4
	DefaultOctave db 5
	DefaultTempo dw 160
	WholeNoteDuration dw ?
	CurrentNoteDuration dw ?
	CurrentNoteDurationLow dw ?
	CurrentNoteDurationHigh dw ?
	CurrentNote db ?
	CurrentFreq dw ?
	CurrentOctave db ?
	IsCis db 0
	NoteC4Freq dw 4561
	NoteC4cisFreq dw 4308  
	NoteD4Freq dw 4063
	NoteD4cisFreq dw 3837
	NoteE4Freq dw 3620
	NoteF4Freq dw 3417
	NoteF4cisFreq dw 3234
	NoteG4Freq dw 3044
	NoteG4cisFreq dw 2873
	NoteA4Freq dw 2712
	NoteA4cisFreq dw 2560
	NoteB4Freq dw 2420
	fColors	    DB	00h, 10h, 20h, 30h, 40h, 50h, 60h, 70h
_data ends

_stack segment stack
	dw	100h dup(0)
top	Label word
_stack ends

end start