MODULE MainModule

    
    
    LOCAL VAR bool bPpToMain:=TRUE;
    LOCAL VAR intnum irTestTrap;
    
    
    
    PROC Main()
        IF bPpToMain Init;
        
        TEST SeqSelect()
        CASE 1000:
            SeqProduct1;
        CASE 2000:
            SeqProduct2;
        CASE 3000:
            SeqProduct3;
        DEFAULT:
            ! Something went wrong
        ENDTEST
    ENDPROC

    
    
    LOCAL PROC Init()
        CONNECT irTestTrap WITH trapTestTrap;
        ITimer 1,irTestTrap;
        
        bPpToMain:=FALSE;
    ENDPROC
    
    
    
    LOCAL TRAP trapTestTrap
        !
    ENDTRAP
    
    
    
ENDMODULE
