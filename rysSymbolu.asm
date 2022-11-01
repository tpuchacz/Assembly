	 ORG 800H  
;Wykonal Tomasz Puchacz - Grupa D7  
	 MVI B,6  
	 MVI D,2  
	 MVI E,1  
	 MVI H,0  
	 MVI L,1  
LEWO 	 MOV C,D  
	 MOV A,C  
	 CPI 0  
	 JZ BRAKSPACJIL  
	 MVI A,' '  
SPACJAL 	 RST 1  
	 DCR C  
	 JNZ SPACJAL  
BRAKSPACJIL 	 MVI A,'&'  
	 MOV C,E  
ZNAKL 	 RST 1  
	 DCR C  
	 JNZ ZNAKL  
PRAWO 	 MOV C,H  
	 MOV A,C  
	 CPI 0  
	 JZ BRAKSPACJIP  
	 MVI A,' '  
SPACJAP 	 RST 1  
	 DCR C  
	 JNZ SPACJAP  
BRAKSPACJIP 	 MVI A,'&'  
	 MOV C,L  
ZNAKP 	 RST 1  
	 DCR C  
	 JNZ ZNAKP  
	 DCR B  
	 MOV A,B  
	 CPI 0  
	 JZ KONIEC  
	 CPI 3  
	 JZ ZAMIANA  
	 CPI 2  
	 JZ DRUGAPOL  
	 CPI 1  
	 JZ DRUGAPOL  
	 DCR D  
	 INR H  
	 INR L  
	 JMP NOWALINIA  
DRUGAPOL 	 INR D  
	 DCR E  
	 DCR H  
NOWALINIA 	 MVI A,10  
	 RST 1  
	 MVI A,13  
	 RST 1  
	 JMP LEWO  
ZAMIANA 	 MOV A,L  
	 MOV L,E  
	 MOV E,A  
	 JMP NOWALINIA  
KONIEC 	 HLT  
