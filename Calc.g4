grammar Calc;

@members {
            private TableSymboles tableSymboles = new TableSymboles(); 
            private int _cur_label = 1;
            /** générateur de nom d'étiquettes pour les boucles */
            private String getNewLabel() { return "B" +(_cur_label++); }
            // ...
        }

start : 
        calcul EOF;


calcul returns [ String code ] 
@init{ $code = new String(); }   // On initialise code, pour ensuite l'utiliser comme accumulateur

@after{ System.out.println($code); }
    :   (decl { $code += $decl.code; })*  //Nouveau code      
        
        NEWLINE*
        
        (instruction { $code += $instruction.code; })*

        { $code += "HALT\n"; } 
    ;

instruction returns [ String code ] 
    : expression finInstruction 
        { 
            $code = $expression.code;
        }
    | assignation finInstruction
        { 
		    $code = $assignation.code;
        }
    | write
        {
            $code = $write.code;
        }
    | read
        {
            $code = $read.code;
        }
    | boucle
        {
            $code = $boucle.code;
        }
    | bloc
        {
            $code = $bloc.code;
        }
    | ifCondition
        {
            $code = $ifCondition.code;
        }
    ;

bloc returns[ String code ]
@init{ $code = new String(); }
    : '{' NEWLINE+ (instruction { $code += $instruction.code; })* '}' NEWLINE*
    ;

expression returns [ String code ]
    : a = expression op = ( '/' | '*' ) b = expression 
        {
            if($op.text.equals("/")){
                $code = $a.code + $b.code + "DIV\n"; 
            }else{ 
                $code = $a.code + $b.code + "MUL\n";
            }
        }
    | c = expression op = ( '+' | '-' ) d = expression 
        {
            if($op.text.equals("+")){
                $code = $c.code + $d.code + "ADD\n"; 
            }else{ 
                $code = $c.code + $d.code + "SUB\n";
            }
        }
    | '(' e = expression ')' {$code = $e.code;}
    | IDENTIFIANT
        {
            AdresseType var = tableSymboles.getAdresseType($IDENTIFIANT.text);
            $code = "PUSHG "+var.adresse+"\n";
        }
    | ENTIER
        {
            $code = "PUSHI " + $ENTIER.text +"\n";
        }
    | '-' f = ENTIER
        {
            $code = "PUSHI 0\n";
            $code += "PUSHI "+$f.text+"\n";
            $code += "SUB\n";
        }
    ;

decl returns [ String code ]
    : TYPE IDENTIFIANT finInstruction
        {
            $code = "PUSHI 0\n";
            tableSymboles.putVar($IDENTIFIANT.text, $TYPE.text);
        }

    | TYPE IDENTIFIANT '=' expression finInstruction
        {
            $code = "PUSHI 0\n";
            $code += $expression.code; //PUSHI x
            tableSymboles.putVar($IDENTIFIANT.text, $TYPE.text); //On sauvegarde la variable
            AdresseType at = tableSymboles.getAdresseType($IDENTIFIANT.text);
            $code += "STOREG "+at.adresse+"\n";
        }
    ; 

assignation returns [ String code ] 
    : IDENTIFIANT '=' expression
        {
            AdresseType at = tableSymboles.getAdresseType($IDENTIFIANT.text); //On récupère l'@ de la variable X
            $code = $expression.code; //PUSHI x (qui peut aussi être le code de l'expression)
            $code += "STOREG "+at.adresse+"\n"; //On stocke la valeur d'expression à l'@ de X
        }
    | IDENTIFIANT operator = ( '++'| '--' )
        {
            AdresseType at = tableSymboles.getAdresseType($IDENTIFIANT.text);
            $code = "PUSHG "+at.adresse+"\n";
            if($operator.text.equals("++")){
                $code += "PUSHI 1\n";
                $code += "ADD\n";
                $code += "STOREG "+at.adresse+"\n"; //On stocke la valeur d'expression à l'@ de X
            }else{
                $code += "PUSHI 1\n";
                $code += "SUB\n";
                $code += "STOREG "+at.adresse+"\n"; //On stocke la valeur d'expression à l'@ de X
            }

        }
    ;

operateur returns [String code]
    : '>'  { $code = "SUP\n"; }
    | '>=' { $code = "SUPEQ\n"; }
    | '<' { $code = "INF\n"; }
    | '<=' { $code = "INFEQ\n"; }
    | '==' { $code = "EQUAL\n"; }
    | '!=' { $code = "NEQ\n"; }
    ;

logique returns [String code]
    : '&&' { $code = "&&"; }
    | '||' { $code = "||"; }
    ;

condition returns [String code]
    : ('true')  
        {
            $code = "PUSHI 1\n";
        }
    | ('false')
        {
            $code = "PUSHI 0\n";
        }
    | a = expression operateur b = expression
        {
            String boucle1 = getNewLabel();
            String exit = getNewLabel();
            $code = $a.code;
            $code += $b.code;
            $code += $operateur.code;
            $code += "JUMPF "+boucle1+"\n";
            $code += "PUSHI 1\n";
            $code += "JUMP "+exit+"\n";
            $code += "LABEL "+ boucle1 + "\n";
            $code += "PUSHI 0\n";
            $code += "LABEL "+exit+"\n";

        }
    | c = condition logique d = condition
        {
            String boucle1 = getNewLabel();
            String exit = getNewLabel();

            if($logique.code.equals("&&")){
                $code = $c.code; //le code c renvoie en dernier 1 ou 0
                $code += "PUSHI 1\n";
                $code += "EQUAL\n";
                $code += "JUMPF "+boucle1+"\n";
                $code += $d.code;
                $code += "PUSHI 1\n";
                $code += "EQUAL\n";
                $code += "JUMPF "+boucle1+"\n";
                $code += "PUSHI 1\n";
                $code += "JUMP "+exit+"\n"; 
            }else{ //OPERATEUR ||
                String or = getNewLabel();
                
                //on test le premier
                $code = $c.code;
                $code += "PUSHI 1\n";
                $code += "EQUAL\n";
                $code += "JUMPF "+or+"\n"; //Si c'est faux on test la deuxième condition
                $code += "PUSHI 1\n"; //Sinon on s'arrête là et on renvoie 1
                $code += "JUMP "+exit+"\n";

                //on test le second
                $code += "LABEL "+or+"\n";
                $code += $d.code;
                $code += "PUSHI 1\n";
                $code += "EQUAL\n"; //si c'est vrai on renvoie 1
                $code += "JUMPF "+boucle1+"\n"; //sinon on renvoie 0
                $code += "PUSHI 1\n";
                $code += "JUMP "+exit+"\n"; 
            }
            $code += "LABEL "+ boucle1 + "\n";
            $code += "PUSHI 0\n"; //false
            $code += "LABEL "+exit+"\n";
        }
    | '!' condition
        {
            String boucle1 = getNewLabel();
            String exit = getNewLabel();

            $code = $condition.code;
            $code += "PUSHI 0\n"; //On test si la négation de condition est égale à 0 (false)
            $code += "EQUAL \n";
            $code += "JUMPF "+boucle1+"\n";
            $code += "PUSHI 1\n";
            $code += "JUMP "+exit+"\n";
            $code += "LABEL "+ boucle1 + "\n";
            $code += "PUSHI 0\n"; //false
            $code += "LABEL "+exit+"\n";
        }
    | '(' condition ')' { $code = $condition.code; }
    ;

boucle returns [ String code ] 
    : 'while(' condition ')' a = instruction
        {
            String boucle1 = getNewLabel();
            String boucle2 = getNewLabel();
            
            $code = "LABEL " + boucle1 + "\n";
            $code += $condition.code;
            $code += "JUMPF "+ boucle2 + "\n";
            $code += $a.code;
            $code += "JUMP "+ boucle1 + "\n";
            $code += "LABEL "+ boucle2 + "\n";
        }
    ;

ifCondition returns [ String code ]
    : 'if(' condition ')' a = instruction 'else' b = instruction
        {
            String elseArea = getNewLabel();
            String exit = getNewLabel();

            $code = $condition.code;
            $code += "JUMPF "+elseArea + "\n";
            $code += $a.code;
            $code += "JUMP "+exit+"\n";
            $code += "LABEL "+elseArea + "\n";
            $code += $b.code;
            $code += "JUMP "+exit+"\n"; 
            $code += "LABEL "+exit+"\n";
        }
    | 'if(' condition ')' a = instruction
        {
            String exit = getNewLabel();

            $code = $condition.code;
            $code += "JUMPF "+exit + "\n";
            $code += $a.code;
            $code += "JUMP "+exit+"\n";
            $code += "LABEL "+exit+"\n";
        }
    ;

write returns [ String code ] 
    : 'write(' expression ')'
        {
            $code = $expression.code;
            $code += "WRITE\n";
            $code += "POP\n";
        }
    ;

read returns [ String code ]
    : 'read(' expression ')'
        {
            $code = $expression.code;
        }
    ;

finInstruction : ( NEWLINE | ';' )+ ;

// lexer
NEWLINE : '\r'? '\n';

WS :   (' '|'\t')+ -> skip  ;

ENTIER: ('0' ..'9')+;

FLOAT : ENTIER+'.'ENTIER+ ;

TYPE : 'int' | 'float' ;

IDENTIFIANT : ('a'..'z')+ ;

UNMATCH : . -> skip ;