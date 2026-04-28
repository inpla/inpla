switch (BASIC(a1)->id) {
case ID_ADD: {
  COUNTUP_INTERACTION(vm);

  BASIC(a1)->id = ID_ADD2;
  VALUE a1port1 = AGENT(a1)->port[1];
  AGENT(a1)->port[1] = a2;
  a2 = a1port1;
  goto loop;
}
case ID_ADD2: {
  COUNTUP_INTERACTION(vm);

  // r << Add(m,n)
  long n = FIX2INT(AGENT(a1)->port[1]);
  long m = FIX2INT(a2);
  a2 = INT2FIX(m + n);
  VALUE a1port0 = AGENT(a1)->port[0];
  free_Agent(a1);
  a1 = a1port0;
  goto loop;
}
case ID_SUB: {
  COUNTUP_INTERACTION(vm);

  BASIC(a1)->id = ID_SUB2;
  VALUE a1port1 = AGENT(a1)->port[1];
  AGENT(a1)->port[1] = a2;
  a2 = a1port1;
  goto loop;
}
case ID_SUB2: {
  COUNTUP_INTERACTION(vm);

  // r << Sub(m,n)
  long n = FIX2INT(AGENT(a1)->port[1]);
  long m = FIX2INT(a2);
  a2 = INT2FIX(m - n);
  VALUE a1port0 = AGENT(a1)->port[0];
  free_Agent(a1);
  a1 = a1port0;
  goto loop;
}
case ID_MUL: {
  COUNTUP_INTERACTION(vm);

  BASIC(a1)->id = ID_MUL2;
  VALUE a1port1 = AGENT(a1)->port[1];
  AGENT(a1)->port[1] = a2;
  a2 = a1port1;
  goto loop;
}
case ID_MUL2: {
  COUNTUP_INTERACTION(vm);

  // r << Mult(m,n)
  long n = FIX2INT(AGENT(a1)->port[1]);
  long m = FIX2INT(a2);
  a2 = INT2FIX(m * n);
  VALUE a1port0 = AGENT(a1)->port[0];
  free_Agent(a1);
  a1 = a1port0;
  goto loop;
}
case ID_DIV: {
  COUNTUP_INTERACTION(vm);

  BASIC(a1)->id = ID_DIV2;
  VALUE a1port1 = AGENT(a1)->port[1];
  AGENT(a1)->port[1] = a2;
  a2 = a1port1;
  goto loop;
}
case ID_DIV2: {
  COUNTUP_INTERACTION(vm);

  // r << DIV(m,n)
  long n = FIX2INT(AGENT(a1)->port[1]);
  long m = FIX2INT(a2);
  a2 = INT2FIX(m / n);
  VALUE a1port0 = AGENT(a1)->port[0];
  free_Agent(a1);
  a1 = a1port0;
  goto loop;
}
case ID_MOD: {
  COUNTUP_INTERACTION(vm);

  BASIC(a1)->id = ID_MOD2;
  VALUE a1port1 = AGENT(a1)->port[1];
  AGENT(a1)->port[1] = a2;
  a2 = a1port1;
  goto loop;
}
case ID_MOD2: {
  COUNTUP_INTERACTION(vm);

  // r << MOD(m,n)
  long n = FIX2INT(AGENT(a1)->port[1]);
  long m = FIX2INT(a2);
  a2 = INT2FIX(m % n);
  VALUE a1port0 = AGENT(a1)->port[0];
  free_Agent(a1);
  a1 = a1port0;
  goto loop;
}
case ID_ERASER: {
  COUNTUP_INTERACTION(vm);

  // Eps ~ (int n)
  free_Agent(a1);
  return;
}

case ID_DUP: {
  COUNTUP_INTERACTION(vm);

  // Dup(x,y) ~ (int n) --> x~n, y~n;
  VALUE a1port = AGENT(a1)->port[0];
  PUSH(vm, a1port, a2);

  a1port = AGENT(a1)->port[1];
  free_Agent(a1);
  a1 = a1port;
  goto loop;
}
}
