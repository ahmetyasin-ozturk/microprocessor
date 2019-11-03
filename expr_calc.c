#include <stdio.h>

int main(){
	int R0 = 0;
				//122 - 9
//	R0 = [(((107|24)--)+!(27&45))++]^!(12-95);

	int a = 107|24;
	a--;
	printf("%d\n", a);
	int b = ~(27&45);
	printf("%d\n", b);
	a = a+b+1;
	int c = ~(12-95);
	printf("%d\n", c);
	b = a^c;
	//printf(b);
	printf("Value of R0 is : %d\nHex Value is : 0x%x", b,b);
	
	return 1;
}



