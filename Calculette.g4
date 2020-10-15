grammar Calculette;

@header {
    import java.util.*;
}

@parser::members {


    private int _cur_label = 0;
    private int nextLabel() { return _cur_label++; }
    private static final String[] _oprels = { "==", "!=", ">", ">=", "<", "<=" };
    private static final String[] _oprelcodes = { "EQUAL", "NEQ", "SUP", "SUPEQ", "INF", "INFEQ" };
    private static final String[] _ops = { "+", "-" , "*" , "/" };
    private static final String[] _opcodes = { "ADD", "SUB","MUL","DIV" };
    private String opRelCode(String op) {
         for (int i = 0; i < _ops.length; i++)
             if (_oprels[i].equals(op)) return _oprelcodes[i];
         System.err.println("Opérateur inconnu : '"+op+"'");
         return "Opérateur inconnu";
     }
    private String opCode(String op) {
         for (int i = 0; i < _ops.length; i++)
             if (_ops[i].equals(op)) return _opcodes[i];
         System.err.println("Opérateur arithmétique inconnu : '"+op+"'");
         return "Opérateur inconnu";
     }

    private int evalexpr (int x, String op, int y) {
        if ( op.equals("*") ){
            return x*y;
        } else if ( op.equals("/") ){
        if(y != 0)
            return x/y;
        else {
          System.err.println("Diviseur nul : '"+op+"'");
          throw new IllegalArgumentException("Diviseur nul : '"+op+"'");
        }
        } else if ( op.equals("+") ){
            return x+y;
        } else if ( op.equals("-") ){
            return x-y;
        } else {
           System.err.println("Opérateur arithmétique incorrect : '"+op+"'");
           throw new IllegalArgumentException("Opérateur arithmétique incorrect : '"+op+"'");
        }
    }

}

start
    : calcul EOF;

calcul returns [ String code ]
@init{ $code = new String(); }   // On initialise $code, pour ensuite l'utiliser comme accumulateur
@after{ System.out.println($code); }
        :   (decl { $code += $decl.code; })*
            { int entry = nextLabel(); $code += "  JUMP " + entry + "\n"; }


            (fonction { $code += $fonction.code; })*


            { $code += "LABEL " + entry + "\n"; }
            (instruction { $code += $instruction.code; })*

            { $code += "  HALT\n"; }
        ;

expr returns [String res]
    : '(' expr ')'
    | a=expr op=('*'|'/'|'+'|'-') b=expr {$res = $a.res + $b.res + opCode($op.text) + "\n"; System.out.println($res);}
    | IDENTIFIANT {
          AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
          int adr = at.adresse;
          if(adr>=0)
              $res="PUSHG "+adr+"\n";
          else
              $res="PUSHL "+adr+"\n";}
    | ENTIER {
          $res = " PUSHI "+$ENTIER.int + "\n";
      }
    | FLOAT { $res = "PUSHF "+$FLOAT.text+"\n";}
    ;

decl returns [ String code ]
        :
            TYPE IDENTIFIANT finInstruction
            {
                $code = " PUSHI 0" +"\n" ;
            }
            | TYPE IDENTIFIANT '=' expr finInstruction
            {
            tablesSymboles.putVar($IDENTIFIANT.text,$TYPE.text);
            AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
                $code = " PUSHI 0" +$expr.res+"STOREG "+at.adresse+"\n";
            }
        ;

instruction returns [ String code ]
        : expr finInstruction
            {
                $code = $expr.res + "  WRITE\n  POP\n";
            }
            | assignation finInstruction
            {
                $code = $assignation.code +"\n" ;
            }
            |READ '('IDENTIFIANT ')' finInstruction
            {
            AdresseType at = tablesSymboles.getAdresseType($IDENTIFIANT.text);
            $code = "READ\n STOREG "+at.adresse+"\n";
            }
            | WRITE '(' IDENTIFIANT ')' finInstruction
            {
              $code = " WRITE "+$IDENTIFIANT.text+ "\n" + "POP"+ "\n";
            }
            | whilecondition {
                $code = $whilecondition.code;
            }
            | if_stat
              {
                    $code = $if_stat.code;
              }
            | for_stat
            {
                  $code = $for_stat.code;
            }
            | do_stat
            {
                  $code = $do_stat.code;
            }
            | fonction
            {
              $code = $fonction.code + "\n";
            }
            | IDENTIFIANT '(' args ')'
                {

                    AdresseType at = tablesSymboles.getFunction($IDENTIFIANT.text);//recuperation de l'adresse et du type de la fonction
                    $code="PUSHI 0\n";
                    $code+=$args.code;
                    $code+="CALL "+at.adresse+"\n";
                    for(int i=0; i<$args.size ; i++){
                        $code += "POP\n";
                    }
                }
            | finInstruction
            {
                $code="";
            }
        ;

assignation returns [ String code ]
        : IDENTIFIANT '=' expr
            {
                $code = $expr.res;
            }
        | TYPE IDENTIFIANT '=' expr
            {
                $code = $expr.res;
            }
        | expr
                {
                    $code = $expr.res;
                }
        ;

whilecondition returns [String code]
              : 'while''(' condition ')' bloc
                {int debutEti =nextLabel();
                  int finEti =nextLabel();
                  $code = "LABEL "+debutEti+"\n"+$condition.code +
                  " JUMPF " + finEti + "\n" +$bloc.code +
                  " JUMP " +debutEti +"\n"+"LABEL " + finEti +"\n";
                }
              ;
condition returns [String code]
            : a=expr oprel=comparateurRel b=expr
           { $code = $a.res + $b.res + "  " + opRelCode($oprel.text) + "\n"; }
            |'true'  { $code = "  PUSHI 1\n"; }
            | 'false' { $code = "  PUSHI 0\n"; }
            ;

            bloc returns [String code]
              @init{ $code = new String(); }
              :   '{' (instruction { $code += $instruction.code; })* '}'
                   NEWLINE*
              ;

if_stat returns [String code]
                      : 'if''('condition')' blocthen=bloc
                            {
                                int finEti =nextLabel();
                              $code =$condition.code +
                              " JUMPF" +finEti+"\n"+
                              $blocthen.code
                               +"LABEL "+finEti;
                            }
                            | 'if''('condition')' blocthen=bloc ('else' blocelse=bloc)?
                            {
                              int sinonEtiq =nextLabel();
                                int finEti =nextLabel();
                              $code =$condition.code +
                              " JUMPF" +sinonEtiq+"\n"+ $blocthen.code+
                               " JUMP"+ finEti+"\n"
                               +"LABEL "+sinonEtiq+"\n"
                               +$blocelse.code
                               +"LABEL "+finEti+"\n";
                            }
                            ;

for_stat returns [String code]
                                  : 'for' '(' a=assignation? ';' c=condition? ';' incr=assignation? ')' b=bloc
                                    {int etiq1=nextLabel();
                                    int etiq2=nextLabel();
                                    $code =$a.code;
                                    $code+="LABEL "+etiq1+"\n";
                                    $code+=$condition.code;
                                    $code+="JUMPF "+etiq2+"\n";
                                    $code+=$b.code;
                                    $code+=$incr.code;
                                    $code+="JUMP "+etiq1+"\n" + "LABEL "+etiq2+"\n";}
                                  ;
do_stat returns [String code]
                                  : 'do' b=bloc 'until' '(' c=condition? ')' finInstruction
                                          {int etiq1=nextLabel();
                                          int etiq2=nextLabel();
                                          $code="LABEL "+etiq1+"\n";
                                          $code+=$b.code;
                                          $code+=$c.code;
                                          $code+="JUMPF "+etiq2+"\n";}
                                  ;

fonction returns [ String code ]
                                  @init{  } // //tablesSymboles = new TablesSymboles();
                                  @after{ } // tablesSymboles = null;
                                      : TYPE
                                          {
                                              int labelFun = nextLabel();
                                          }
                                          IDENTIFIANT '('  params ? ')'
                                          {
                                          tablesSymboles.newFunction($IDENTIFIANT.text, label, $TYPE.text);
                                          tablesSymboles.putVar("return",$TYPE.text);
                                          $code="LABEL "+labelFun+"\n";
                                          }
                                          bloc
                                          {
                                              $code=$bloc.code + "RETURN" + "\n";
                                          }
                                      ;


params
                                      : TYPE IDENTIFIANT
                                          {
                                              tablesSymboles.putVar($IDENTIFIANT.text,"int");
                                          }
                                          ( ',' TYPE IDENTIFIANT
                                              {
                                                  tablesSymboles.putVar($IDENTIFIANT.text,"int");
                                              }
                                          )*
                                      ;

                                   // init nécessaire à cause du ? final et donc args peut être vide (mais $args sera non null)
args returns [ String code, int size] @init{ $code = new String(); $size = 0; }
                                      : ( expression
                                      {
                                          $code=$expression.code; $size=$size+1;
                                      }
                                      ( ',' expression
                                      {
                                          $code+=$expression.code; $size=$size+1;
                                      }
                                      )*
                                        )?
                                      ;

expression returns [ String code, String type ]
                                      :
                                      //...
                                      | IDENTIFIANT '(' args ')'                  // appel de fonction
                                      {
                                        int labelBis = nextLabel();
                                        String pops="POP \n";
                                        for(int i=0;i<$args.size;i++){
                                          pops+="POP \n";
                                        }
                                        //AdresseType at = TableSymboles.getAdresseType($IDENTIFIANT.text);
                                        //$type=at.type;
                                        $code="LABEL "+labelBis+"\n"+
                                        $args.code+"CALL 0\n"+pops+"WRITE \n";
                                      }
                                      ;
comparateurRel
              : GT | GE | LT | LE | EQ
                    ;

comBinary
              : AND | OR | NOT
                    ;
finInstruction : ( NEWLINE | ';' )+ ;

// lexer
TYPE : 'int' | 'float' ;
READ : 'readln';
WRITE : 'println';
NEWLINE : '\r'? '\n';
GT         : '>' ;
GE         : '>=' ;
LT         : '<' ;
LE         : '<=' ;
EQ         : '==' ;
AND        : '&&' ;
OR         : '||' ;
NOT        : '!';
WS :   (' '|'\t')+ -> skip  ;
IDENTIFIANT :   ('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*;
ENTIER : ('0'..'9')+  ;
FLOAT : ENTIER '.' ('0'..'9')*;
DECIMAL : ('0' .. '9')+(',' ('0'..'9')+)? ;

UNMATCH : . -> skip ;
