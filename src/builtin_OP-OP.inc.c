switch (BASIC(a1)->id) {

case ID_ERASER: {
  // Eps ~ Alpha(a1,...,a5)
  COUNTUP_INTERACTION(vm);

  int arity = IdTable_get_arity(BASIC(a2)->id);
  switch (arity) {
  case 0: {
    free_Agent2(a1, a2);
    return;
  }

  case 1: {
    VALUE a2p0 = AGENT(a2)->port[0];
    free_Agent(a2);
    a2 = a2p0;
    goto loop;
  }

  default:
    for (int i = 1; i < arity; i++) {
      VALUE a2port = AGENT(a2)->port[i];
      VALUE eps = make_Agent(vm, ID_ERASER);
      PUSH(vm, eps, a2port);
    }

    VALUE a2p0 = AGENT(a2)->port[0];
    free_Agent(a2);
    a2 = a2p0;
    goto loop;
  }
} break;

case ID_DUP: {
  // Dup(p1,p2) ~ Alpha(b1,...,b5)
  COUNTUP_INTERACTION(vm);

  if (BASIC(a2)->id == ID_DUP) {
    // Dup(p1,p2) >< Dup(b1,b2) => p1~b1, b2~b2;
    VALUE a1p = AGENT(a1)->port[0];
    VALUE a2p = AGENT(a2)->port[0];
    PUSH(vm, a1p, a2p);

    a1p = AGENT(a1)->port[1];
    a2p = AGENT(a2)->port[1];

    free_Agent2(a1, a2);
    a1 = a1p;
    a2 = a2p;
    goto loop;
  }

  int arity = IdTable_get_arity(BASIC(a2)->id);
  switch (arity) {
  case 0: {
    // Dup(p0,p1) >< A => p0~A, p1~A;
    VALUE a1p = AGENT(a1)->port[0];
    VALUE new_a2 = make_Agent(vm, BASIC(a2)->id);
    PUSH(vm, a1p, new_a2);

    a1p = AGENT(a1)->port[1];
    free_Agent(a1);
    a1 = a1p;
    goto loop;
  }

    // a2p0 などが fixint の場合は即座に複製させる
  case 1: {
    // Dup(p0,p1) >< A(a2p0) => p1~A(w2), p0~A(w1),
    //                          Dup(w1,w2)~a2p0;
    // Dup(p0,p1) >< A(int a2p0) => p1~A(a2p0), p0~A(a2p0);

    VALUE a2p0 = AGENT(a2)->port[0];

    int a2id = BASIC(a2)->id;

    // p1
    VALUE new_a2 = make_Agent(vm, a2id);

    if (IS_FIXNUM(a2p0)) {
      AGENT(new_a2)->port[0] = a2p0;
      PUSH(vm, AGENT(a1)->port[1], new_a2);
      AGENT(a2)->port[0] = a2p0;

      VALUE a1p0 = AGENT(a1)->port[0];
      free_Agent(a1);

      // PUSH(vm, a1p0, a2);
      a1 = a1p0;
      goto loop;

    } else {
      VALUE w = make_Name(vm);
      AGENT(new_a2)->port[0] = w;
      PUSH(vm, AGENT(a1)->port[1], new_a2);
      AGENT(a1)->port[1] = w; // for (*L)dup

      w = make_Name(vm);
      AGENT(a2)->port[0] = w;
      PUSH(vm, AGENT(a1)->port[0], a2);

      AGENT(a1)->port[0] = w; // for (*L)dup

      a2 = a2p0;
      goto loop;
    }

  } break;

  case 2: {
    // Here we only manage the following rule,
    // and the other will be done at the next case:
    //   Dup(p0,p1) >< Cons(int i, a2p1) =>
    //     p0~Cons(i,w), p1~(*R)Cons(i,ww), (*L)Dup(w,ww)~a2p1;

    VALUE a2p0 = AGENT(a2)->port[0];
    if (IS_FIXNUM(a2p0)) {
      int a2id = BASIC(a2)->id;
      VALUE new_a2 = make_Agent(vm, a2id);

      AGENT(new_a2)->port[0] = a2p0;

      VALUE w = make_Name(vm);
      AGENT(new_a2)->port[1] = w;

      PUSH(vm, AGENT(a1)->port[0], new_a2);
      AGENT(a1)->port[0] = w;

      VALUE a2p1 = AGENT(a2)->port[1];
      VALUE ww = make_Name(vm);
      AGENT(a2)->port[1] = ww;

      PUSH(vm, AGENT(a1)->port[1], a2);
      AGENT(a1)->port[1] = ww;

      a2 = a2p1;
      goto loop;
    }

    // otherwise: goto default
    // So, DO NOT put break.
  }

  default: {
    // Dup(p0,p1) >< A(a2p0, a2p1) =>
    //      p0~A(w0,w1),        (*L)Dup(w0,ww0)~a2p0
    //      p1~(*R)A(ww0,ww1),      Dup(w1,ww1)~a2p1,

    // Dup(p0,p1) >< A(a2p0, a2p1, a2p2) =>
    //      p0~A(w0,w1,w2),        (*L)Dup(w0,ww0)~a2p0
    //      p1~(*R)A(ww0,ww1,ww2),     Dup(w1,ww1)~a2p1,
    //                                 Dup(w2,ww2)~a2p2;

    // Dup(p0,p1) >< A(a2p0, a2p1, a2p2 a2p3) =>
    //      p0~A(w0,w1,w2,w3),         (*L)Dup(w0,ww0)~a2p0
    //      p1~(*R)A(ww0,ww1,ww2,ww3),     Dup(w1,ww1)~a2p1,
    //                                     Dup(w2,ww2)~a2p2,
    //                                     Dup(w3,ww3)~a2p3;

    // Dup(p0,p1) >< A(a2p0, int a2p1, a2p2 a2p3) =>
    //      p0~A(w0,a2p1,w2,w3),         (*L)Dup(w0,ww0)~a2p0
    //      p1~(*R)A(ww0,a2p1,ww2,ww3),
    //                                     Dup(w2,ww2)~a2p2,
    //                                     Dup(w3,ww3)~a2p3;

    // newA = mkAgent(A);
    // for (i=0; i<arity; i++) {
    //   if (!IS_FIXNUM(a2->p[i])) {
    //      newA->p[i] = w_i;
    //   } else {
    //      newA->p[i] = a2->p[i];
    //   }
    // }
    // for (i=1; i<arity; i++) {
    //   if (!IS_FIXNUM(a2->p[i])) {
    //     newDup( newA->p[i], newWW_i) ~ a2[i]
    //     a2[i] = newWW_i;
    //   }
    // }
    // if (!IS_FIXNUM(a2->p[0])) {
    //   p0_preserve = p0;
    //   p1_preserve = p1;
    //   (*L)Dup(w0, newWW0) ~ a2[0] // this destroys the p0 and p1.
    //
    //   p0_preserve ~ newA
    //   a2[0] = newWW0;
    //
    //   p1_preserve ~ a2; <-- This will be `goto loop'.
    // } else {
    //   p0 ~ newA;
    //   p1_preserve = p1;
    //   free_Agent((*L)Dup);
    //   p1_preserve ~ a2; >-- This will be `goto loop'.
    // }

    int a2id = BASIC(a2)->id;
    VALUE new_a2 = make_Agent(vm, a2id);
    for (int i = 0; i < arity; i++) {
      VALUE a2pi = AGENT(a2)->port[i];
      if (!IS_FIXNUM(a2pi)) {
        AGENT(new_a2)->port[i] = make_Name(vm);
      } else {
        AGENT(new_a2)->port[i] = a2pi;
      }
    }

    for (int i = 1; i < arity; i++) {
      VALUE a2pi = AGENT(a2)->port[i];

      if (!IS_FIXNUM(a2pi)) {

        VALUE new_dup = make_Agent(vm, ID_DUP);
        AGENT(new_dup)->port[0] = AGENT(new_a2)->port[i];

        VALUE new_ww = make_Name(vm);
        AGENT(new_dup)->port[1] = new_ww;

        PUSH(vm, new_dup, a2pi);

        AGENT(a2)->port[i] = new_ww;
      }
    }

    VALUE a2p0 = AGENT(a2)->port[0];
    if (!IS_FIXNUM(a2p0)) {

      VALUE a1p0 = AGENT(a1)->port[0];
      VALUE a1p1 = AGENT(a1)->port[1];

      AGENT(a1)->port[0] = AGENT(new_a2)->port[0];
      VALUE new_ww = make_Name(vm);
      AGENT(a1)->port[1] = new_ww;
      PUSH(vm, a1, a2p0);

      PUSH(vm, a1p0, new_a2);

      AGENT(a2)->port[0] = new_ww;

      a1 = a1p1;

      goto loop;
    } else {
      PUSH(vm, AGENT(a1)->port[0], new_a2);
      VALUE a1p1 = AGENT(a1)->port[1];
      free_Agent(a1);

      a1 = a1p1;
      goto loop;
    }
  }
  }
} break;

case ID_TUPLE0:
  if (BASIC(a2)->id == ID_TUPLE0) {
    // [] ~ [] --> nothing
    COUNTUP_INTERACTION(vm);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);
    return;
  }

  break; // end ID_TUPLE0

case ID_TUPLE2:
  if (BASIC(a2)->id == ID_TUPLE2) {
    // (x1,x2) ~ (y1,y2) --> x1~y1, x2~y2
    COUNTUP_INTERACTION(vm);

    VALUE a1p1 = AGENT(a1)->port[1];
    VALUE a2p1 = AGENT(a2)->port[1];
    PUSH(vm, a1p1, a2p1);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);
    a1 = AGENT(a1)->port[0];
    a2 = AGENT(a2)->port[0];
    goto loop;
  }

  break; // end ID_TUPLE2

case ID_TUPLE3:
  if (BASIC(a2)->id == ID_TUPLE3) {
    // (x1,x2,x3) ~ (y1,y2,y3) --> x1~y1, x2~y2, x3~y3
    COUNTUP_INTERACTION(vm);

    PUSH(vm, AGENT(a1)->port[2], AGENT(a2)->port[2]);
    PUSH(vm, AGENT(a1)->port[1], AGENT(a2)->port[1]);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);
    a1 = AGENT(a1)->port[0];
    a2 = AGENT(a2)->port[0];
    goto loop;
  }

  break; // end ID_TUPLE2

case ID_TUPLE4:
  if (BASIC(a2)->id == ID_TUPLE4) {
    // (x1,x2,x3) ~ (y1,y2,y3) --> x1~y1, x2~y2, x3~y3
    COUNTUP_INTERACTION(vm);

    PUSH(vm, AGENT(a1)->port[3], AGENT(a2)->port[3]);
    PUSH(vm, AGENT(a1)->port[2], AGENT(a2)->port[2]);
    PUSH(vm, AGENT(a1)->port[1], AGENT(a2)->port[1]);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);
    a1 = AGENT(a1)->port[0];
    a2 = AGENT(a2)->port[0];
    goto loop;
  }

  break; // end ID_TUPLE2

case ID_TUPLE5:
  if (BASIC(a2)->id == ID_TUPLE5) {
    // (x1,x2,x3) ~ (y1,y2,y3) --> x1~y1, x2~y2, x3~y3
    COUNTUP_INTERACTION(vm);

    PUSH(vm, AGENT(a1)->port[4], AGENT(a2)->port[4]);
    PUSH(vm, AGENT(a1)->port[3], AGENT(a2)->port[3]);
    PUSH(vm, AGENT(a1)->port[2], AGENT(a2)->port[2]);
    PUSH(vm, AGENT(a1)->port[1], AGENT(a2)->port[1]);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);
    a1 = AGENT(a1)->port[0];
    a2 = AGENT(a2)->port[0];
    goto loop;
  }

  break; // end ID_TUPLE2

case ID_NIL:
  if (BASIC(a2)->id == ID_NIL) {
    // [] ~ [] --> nothing
    COUNTUP_INTERACTION(vm);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);

    return;
  }

  break; // end ID_NIL

case ID_CONS:
  if (BASIC(a2)->id == ID_CONS) {
    // a:b ~ c:d --> a~c, b~d
    COUNTUP_INTERACTION(vm);

    VALUE a1p1 = AGENT(a1)->port[1];
    VALUE a2p1 = AGENT(a2)->port[1];
    PUSH(vm, a1p1, a2p1);

    //	      free_Agent(a1);
    //	      free_Agent(a2);
    free_Agent2(a1, a2);
    a1 = AGENT(a1)->port[0];
    a2 = AGENT(a2)->port[0];
    goto loop;
  }

  break; // end ID_CONS

  // built-in funcAgent for lists and tuples
case ID_APPEND:
  switch (BASIC(a2)->id) {
  case ID_NIL: {
    // App(r,a) >< [] => r~a;
    COUNTUP_INTERACTION(vm);

    VALUE a1p0 = AGENT(a1)->port[0];
    VALUE a1p1 = AGENT(a1)->port[1];
    //		free_Agent(a1);
    //		free_Agent(a2);
    free_Agent2(a1, a2);
    a1 = a1p0;
    a2 = a1p1;
    goto loop;
  }

  case ID_CONS: {
    // App(r,a) >< x:xs => r~(*R)x:w, (*L)App(w,a)~xs;
    COUNTUP_INTERACTION(vm);

    VALUE a1p0 = AGENT(a1)->port[0];
    VALUE a2p1 = AGENT(a2)->port[1];
    VALUE w = make_Name(vm);

    AGENT(a2)->port[1] = w;
    PUSH(vm, a1p0, a2);
    // VM_EQStack_Push(vm, a1p1, a2);

    AGENT(a1)->port[0] = w;
    a2 = a2p1;
    goto loop;
  }
  }

  break; // end ID_APPEND

case ID_ZIP:
  switch (BASIC(a2)->id) {
  case ID_NIL: {
    // Zip(r, blist) >< [] => r~[], blist~Eraser;
    COUNTUP_INTERACTION(vm);

    VALUE a1p0 = AGENT(a1)->port[0];
    VALUE a1p1 = AGENT(a1)->port[1];

    // Eraser
    BASIC(a1)->id = ID_ERASER;
    PUSH(vm, a1p1, a1);

    a1 = a1p0;
    goto loop;
  }

  case ID_CONS: {
    // Zip(r, blist) >< x:xs => Zip_Cons(r,x:xs)~blist;
    COUNTUP_INTERACTION(vm);

    VALUE a1p1 = AGENT(a1)->port[1];

    BASIC(a1)->id = ID_ZIPC;
    AGENT(a1)->port[1] = a2;
    a2 = a1p1;
    goto loop;
  }
  }

  break; // end ID_ZIP

case ID_ZIPC:
  switch (BASIC(a2)->id) {
  case ID_NIL: {
    // Zip_Cons(r, x:xs)><[] => r~[], x:xs~Eraser;
    COUNTUP_INTERACTION(vm);

    VALUE a1p0 = AGENT(a1)->port[0];
    VALUE a1p1 = AGENT(a1)->port[1];

    // Eraser
    BASIC(a1)->id = ID_ERASER;
    PUSH(vm, a1p1, a1);

    a1 = a1p0;
    goto loop;
  }

  case ID_CONS: {
    // Zip_Cons(r, (*1)x:xs) >< y:ys =>
    //    r~(*R)((*1)(y,x):ws), (*L)Zip(ws,ys)~xs;
    COUNTUP_INTERACTION(vm);

    VALUE r = AGENT(a1)->port[0];
    VALUE inner_cons = AGENT(a1)->port[1];
    VALUE xs = AGENT(inner_cons)->port[1];
    VALUE ys = AGENT(a2)->port[1];

    // (*1)(y,x)
    BASIC(inner_cons)->id = ID_TUPLE2;
    VALUE x = AGENT(inner_cons)->port[0];
    VALUE y = AGENT(a2)->port[0];
    AGENT(inner_cons)->port[0] = y;
    AGENT(inner_cons)->port[1] = x;

    // (*R)((*1)(y,x):ws)
    VALUE ws = make_Name(vm);
    AGENT(a2)->port[0] = inner_cons;
    AGENT(a2)->port[1] = ws;

    PUSH(vm, r, a2);

    // (*L)Zip(ws,ys)~xs;
    BASIC(a1)->id = ID_ZIP;
    AGENT(a1)->port[0] = ws;
    AGENT(a1)->port[1] = ys;
    a2 = xs;
    goto loop;
  }
  }

  break; // end ID_ZIPC

case ID_MAP:
  switch (BASIC(a2)->id) {
  case ID_NIL: {
    // Map(result, f) >< []   => result~[], Eraser~f;
    COUNTUP_INTERACTION(vm);

    VALUE a1p0 = AGENT(a1)->port[0];
    VALUE a1p1 = AGENT(a1)->port[1];

    // Eraser
    BASIC(a1)->id = ID_ERASER;
    PUSH(vm, a1, a1p1);

    a1 = a1p0;
    goto loop;
  }

  case ID_CONS: {
    COUNTUP_INTERACTION(vm);

    VALUE a1p0 = AGENT(a1)->port[0];
    VALUE a1p1 = AGENT(a1)->port[1];

    VALUE a2p0 = AGENT(a2)->port[0];
    VALUE a2p1 = AGENT(a2)->port[1];
    VALUE w = make_Name(vm);
    VALUE ws = make_Name(vm);

    VALUE pair = make_Agent(vm, ID_TUPLE2);

    AGENT(a2)->port[0] = w;
    AGENT(a2)->port[1] = ws;
    PUSH(vm, a1p0, a2);

    /*
    if ((IS_NAMEID(BASIC(a1p1)->id))
        && (NAME(a1p1)->port != NULL)) {
          VALUE a1p1_agent = NAME(a1p1)->port;
          free_Name(a1p1);
          AGENT(a1)->port[1] = a1p1_agent;
    }
    */

    if (BASIC(a1p1)->id == ID_PERCENT) {
      // special case
      // Map(result, %f) >< x:xs =>
      //		  result~w:ws,
      //		  %f ~ (w, x), Map(ws, %f)~xs;

      AGENT(pair)->port[0] = w;
      AGENT(pair)->port[1] = a2p0;
      VALUE new_percent = make_Agent(vm, ID_PERCENT);
      AGENT(new_percent)->port[0] = AGENT(a1p1)->port[0];
      PUSH(vm, new_percent, pair);

      AGENT(a1)->port[0] = ws;
      a2 = a2p1;
      goto loop;
    }

    //     Map(result, f) >< x:xs => Dup(f1,f2)~f,
    //                            result~w:ws,
    //                            f1 ~ (w, x), map(ws, f2)~xs;

    VALUE dup = make_Agent(vm, ID_DUP);
    VALUE f1 = make_Name(vm);
    VALUE f2 = make_Name(vm);
    AGENT(dup)->port[0] = f1;
    AGENT(dup)->port[1] = f2;
    PUSH(vm, dup, a1p1);

    AGENT(pair)->port[0] = w;
    AGENT(pair)->port[1] = a2p0;
    PUSH(vm, f1, pair);

    AGENT(a1)->port[0] = ws;
    AGENT(a1)->port[1] = f2;
    a2 = a2p1;
    goto loop;
  }
  }

  break; // end ID_MAP

case ID_MERGER:
  switch (BASIC(a2)->id) {
  case ID_TUPLE2: {
    // MG(r) ~ (a|b) => *MGp(*r)~a, *MGp(*r)~b
    COUNTUP_INTERACTION(vm);

    BASIC(a1)->id = ID_MERGER_P;
    AGENT(a1)->port[1] = (VALUE)NULL;
    AGENT(a1)->port[2] = (VALUE)NULL;
    PUSH(vm, a1, AGENT(a2)->port[1]);
    PUSH(vm, a1, AGENT(a2)->port[0]);
    free_Agent(a2);
    return;
  }
  }
  break; // end ID_MG

case ID_MERGER_P:
  switch (BASIC(a2)->id) {
  case ID_NIL:
    // *MGP(r)~[]
#ifndef THREAD

    COUNTUP_INTERACTION(vm);

    if (AGENT(a1)->port[1] == (VALUE)NULL) {
      AGENT(a1)->port[1] = a2;
      return;
    } else {
      VALUE a1p0 = AGENT(a1)->port[0];
      //		free_Agent(AGENT(a1)->port[1]);
      //		free_Agent(a1);
      free_Agent2(AGENT(a1)->port[1], a1);

      a1 = a1p0;
      goto loop;
    }
#else
    // AGENT(a1)->port[2] is used as a lock for NIL case
    if (AGENT(a1)->port[2] == (VALUE)NULL) {
      if (!(__sync_bool_compare_and_swap(&(AGENT(a1)->port[2]), NULL, a2))) {
        // something exists already
        goto loop;

      } else {
        return;
      }
    } else if ((AGENT(a1)->port[2] != (VALUE)NULL) &&
               (BASIC(AGENT(a1)->port[2])->id == ID_NIL)) {

      COUNTUP_INTERACTION(vm);

      VALUE a1p0 = AGENT(a1)->port[0];
      //		free_Agent(AGENT(a1)->port[2]);
      //		free_Agent(a1);
      free_Agent2(AGENT(a1)->port[2], a1);
      a1 = a1p0;
      goto loop;
    } else {
      goto loop;
    }

#endif
  case ID_CONS:
    // *MGP(r)~x:xs => r~x:w, *MGP(w)~xs;
    {
#ifndef THREAD

      COUNTUP_INTERACTION(vm);

      VALUE a1p0 = AGENT(a1)->port[0];
      VALUE w = make_Name(vm);
      AGENT(a1)->port[0] = w;
      PUSH(vm, a1, AGENT(a2)->port[1]);

      AGENT(a2)->port[1] = w;
      a1 = a1p0;
      goto loop;
#else
      // AGENT(a1)->port[1] is used as a lock for CONS case
      // AGENT(a1)->port[2] is used as a lock for NIL case

      if (AGENT(a1)->port[2] != (VALUE)NULL) {
        // The other MGP finished still, so:
        // *MGP(r)~x:xs => r~x:xs;

        COUNTUP_INTERACTION(vm);

        VALUE a1p0 = AGENT(a1)->port[0];
        //		  free_Agent(AGENT(a1)->port[2]);   // free the lock for
        // NIL 		  free_Agent(a1);
        free_Agent2(AGENT(a1)->port[2], a1);
        a1 = a1p0;
        goto loop;

      } else if (AGENT(a1)->port[1] == (VALUE)NULL) {
        if (!(__sync_bool_compare_and_swap(&(AGENT(a1)->port[1]), NULL, a2))) {
          // Failure to be locked.
          goto loop;
        }

        // Succeed the lock
        COUNTUP_INTERACTION(vm);

        VALUE a1p0 = AGENT(a1)->port[0];
        VALUE w = make_Name(vm);
        AGENT(a1)->port[0] = w;
        PUSH(vm, a1, AGENT(a2)->port[1]);

        AGENT(a2)->port[1] = w;

        AGENT(a1)->port[1] = (VALUE)NULL; // free the lock

        a1 = a1p0;

        goto loop;

      } else {
        // MPG works for the other now.

        goto loop;
      }

#endif
    }
  }
  break; // end ID_MERGER_P

case ID_PERCENT:

  if (BASIC(a2)->id == ID_TUPLE2) {

    // %foo >< @(args, s)
    int percented_id = FIX2INT(AGENT(a1)->port[0]);
    int arity = IdTable_get_arity(percented_id);

    if (arity < 1) {
      printf("Rumtime error: `%s' has no arity.\n",
             IdTable_get_name(percented_id));
      puts_term(a1);
      printf("~");
      puts_term(a2);
      puts("");

      if (yyin != stdin)
        exit(-1);
#ifndef THREAD
      mark_and_sweep();
      return;
#else
      printf("Retrieve is not supported in the multi-threaded version.\n");
      exit(-1);
#endif
    }

    COUNTUP_INTERACTION(vm);

    switch (arity) {
    case 1: {
      BASIC(a2)->id = percented_id;
      free_Agent(a1);
      a1 = a2;
      a2 = AGENT(a2)->port[1];
      goto loop;
    }

    default: {
      VALUE a2p0 = AGENT(a2)->port[0];
      VALUE a2p0_id = BASIC(a2p0)->id;
      if ((IS_AGENTID(a2p0_id)) && (IS_TUPLEID(a2p0_id)) &&
          (GET_TUPLEARITY(a2p0_id) == arity)) {
        //    %foo2 ~ ((p1,p2),q) --> foo2(p1,p2)~q
        BASIC(a2p0)->id = percented_id;
        free_Agent(a1);
        VALUE preserved_q = AGENT(a2)->port[1];
        free_Agent(a2);

        a1 = a2p0;
        a2 = preserved_q;
        goto loop;

      } else {
        //    %foo2 ~ (p,q) --> foo2(p1,p2)~q, (p1,p2)~p
        VALUE preserved_p = AGENT(a2)->port[0];
        VALUE preserved_q = AGENT(a2)->port[1];
        VALUE tuple = a2;
        BASIC(a1)->id = percented_id;
        for (int i = 0; i < arity; i++) {
          VALUE new_name = make_Name(vm);
          AGENT(a1)->port[i] = new_name;
          AGENT(tuple)->port[i] = new_name;
        }
        PUSH(vm, tuple, preserved_p);

        a2 = preserved_q;
        goto loop;
      }
    }
    }
  }
  break; // end ID_PERCENT

} // end switch(BASIC(a1)->id)
