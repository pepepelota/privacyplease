#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <time.h>

char serial_number[20]="";
unsigned int valor;
int prim;
char snid[17]="\0";

char gen_sn() {
    char sn1[5];
    char sn2[5];
    char sn3[5];
    char sn4[5];
    char cnid[2];
    int randnum;
    // static char state1[32000];
    // initstate( time(NULL), state1, sizeof(state1));

    while (strlen(snid) < 16) {
      randnum = 90 * (rand() / (RAND_MAX + 1.0));
      randnum = randnum + '0';
      if (((randnum>='A' && randnum<='Z')) || ((randnum>='0' && randnum<='9'))) {
         sprintf(snid,"%s%c", snid,randnum);
      }
    }
    // printf("EL SERIAL ES %s\n", snid);
    sprintf(sn1,"%c%c%c%c",snid[0],snid[1],snid[2],snid[3]);
    sprintf(sn2,"%c%c%c%c",snid[4],snid[5],snid[6],snid[7]);
    sprintf(sn3,"%c%c%c%c",snid[8],snid[9],snid[10],snid[11]);
    sprintf(sn4,"%c%c%c%c",snid[12],snid[13],snid[14],snid[15]);
    sprintf(serial_number,"%s-%s-%s-%s", sn1, sn2, sn3, sn4);
    return;
};


int value() {
    long int subval;
    subval = snid[0]*1 + snid[1]*3 + snid[2]*7 + snid[3]*11 + snid[4]*17 + snid[5]*23 + snid[6]*29 + snid[7]*31 + snid[8]*37 + snid[9]*41 + snid[10]*43 + snid[11]*47 + snid[12]*53 + snid[13]*59 + snid[14]*61 + snid[15]*5;
    valor=subval;
    return subval;

}


int check_prim() {
    int i=2;
    prim=1;
//    valor=0;
    while ( i < valor ) {
        // printf("K: %i\n", i);
        if (valor % i == 0) {
            prim=0;
            break;
        }
        i++;
    }
}


void replace() {
    char snid_tmp[17]="";
    int j;
    for (j=0; j<20; j++) {
      if ( snid[j] !=  45 ) {
        sprintf(snid_tmp,"%s%c", snid_tmp,snid[j]);
      }
    }
    sprintf(snid,"%s",snid_tmp);
}





int main (int argc, char *argv[]) {
  if (argv[1]) {
      sprintf(snid,"%s",argv[1]);
      replace();
      value();
      check_prim();
      if (prim == 1) printf("OK\n");
      if (prim == 0) printf("KO\n");
  }
  else {
    static char state1[32000];
    initstate( time(NULL), state1, sizeof(state1));
    prim=0;
    while(prim == 0) {
      sprintf(snid,"");
      // initstate( valor, state1, sizeof(state1));
      gen_sn();
      value();
      check_prim();
      // printf("Valor:  %i\n", valor);
    }

    // char *valor;
    // sprintf(valor,"%i", value());

    printf("%s\n", serial_number);
    // printf("El val es %i\n", valor);
    return;
  }

}
