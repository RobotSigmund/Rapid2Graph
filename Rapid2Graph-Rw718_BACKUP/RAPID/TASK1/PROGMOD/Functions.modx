MODULE Functions(NOSTEPIN)



    FUNC num SeqSelect()
        VAR num nSelectedSeq;
        VAR num nValidSeq{5}:=[1000,2000,3000];

        ! Select a random sequence
        nSelectedSeq:=nValidSeq{Trunc(Rand()/RAND_MAX*Dim(nValidSeq,1))+1};

        RETURN nSelectedSeq;
    ENDFUNC



ENDMODULE
