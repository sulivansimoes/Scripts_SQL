use Protheus

DECLARE @Contador int = 0;
DECLARE @QuantidadeTabelas int
DECLARE @NomeTabela nvarchar(500) ;
DECLARE @Linhas  int;
DECLARE @Query nvarchar(max) = '';
DECLARE @QueryAux nvarchar(max) = '';

DECLARE TodasTabelas cursor for
SELECT SUM(partitions.rows) AS '@Linhas',
	   dbtables.name AS 'tabela'
FROM sys.tables AS dbtables
JOIN sys.partitions AS partitions ON dbtables.object_id = partitions.object_id AND partitions.index_id in (0,1)
WHERE dbtables.[name]  NOT LIKE '%TOP_%'
GROUP BY schema_name(schema_id), dbtables.name
HAVING SUM(partitions.rows) > 0

--Obtendo quantas tabelas que possuem dados
SET @QuantidadeTabelas = (  SELECT MAX(LINHA) FROM( SELECT  ROW_NUMBER() OVER(ORDER BY dbtables.name DESC) AS LINHA
					  							    FROM sys.tables AS dbtables
												    JOIN sys.partitions AS partitions ON dbtables.object_id = partitions.object_id AND partitions.index_id in (0,1)
												    WHERE dbtables.[name]  NOT LIKE '%TOP_%'
												    GROUP BY schema_name(schema_id), dbtables.name
												    HAVING SUM(partitions.rows) > 0 ) AS TMP )												

OPEN TodasTabelas 
FETCH NEXT FROM TodasTabelas  
INTO @Linhas, @NomeTabela

PRINT 'Processo iniciado';
PRINT 'Analisando '+CAST(@QuantidadeTabelas AS NVARCHAR(50)) +' tabelas';

WHILE @contador < @QuantidadeTabelas
	BEGIN 

		SET @QueryAux = ' SELECT Tabela,'
					  +			' Deletados,'
					  +			' Nao_deletados,'
					  +			' CASE' 
					  +				' WHEN Nao_deletados > 0 THEN ( CAST( CAST(Deletados AS FLOAT) / CAST(Nao_deletados AS FLOAT) * 100 AS INT)) '
					  +				' ELSE 0 '
					  +			' END AS ''% Registros Deletados'''
					  + ' FROM ( ' 
					  + ' SELECT '
					  +          ''''+@NomeTabela+''' AS Tabela,'
					  +		   ' COUNT(*) AS Deletados, '
					  +        ' ( SELECT COUNT(*) FROM '+ @NomeTabela +' WHERE ' + @NomeTabela + '.D_E_L_E_T_ = '''' ) AS Nao_deletados '					  
				      + ' FROM ' + @NomeTabela 
				      + ' WHERE ' + @NomeTabela + '.D_E_L_E_T_ = ''*'' '
					  + ') AS TMP'
					  + ' GROUP BY Tabela, Deletados, Nao_deletados'
					  + CHAR(13)+CHAR(10)

		IF @contador < @QuantidadeTabelas -1
			BEGIN				
				SET @QueryAux += ' UNION ALL'
			END

		PRINT CHAR(13)+CHAR(10) + @QueryAux 

		SET @Query += @QueryAux

		SET @contador += 1;

		FETCH NEXT FROM TodasTabelas  
		INTO @Linhas, @NomeTabela
	END

-- Ordena as tabelas que tem mais registros deletados primeiro
SET @Query += ' ORDER BY Deletados DESC'

-- Executa a query que foi construída
EXEC( @Query )

CLOSE TodasTabelas 
DEALLOCATE TodasTabelas

PRINT 'Processo concluído';
GO
