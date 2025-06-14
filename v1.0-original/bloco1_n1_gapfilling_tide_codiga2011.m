%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 1: Preenchimento de Falhas Amostrais com Previs�o de Mar�
%
% Aplica��o: Dados de N�VEL DO MAR de ADCP da B�ia BH07, na Ba�a de 
% Guanabara.
%
% Utiliza-se o pacote U-Tide de Codiga (2011) para preencher as falhas 
% com previs�o de mar�.
%
% Hatsue Takanaca de Decco, Abril/2025.
%
% Contribui��es de IA: 
% ------------------------------------------------------------
% Este script foi desenvolvido com o aux�lio das intelig�ncias
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio de 2025,
% e Gemini (Gooogle AI) em junho de 2025. 
% A l�gica foi constru�da a partir de instru��es e ajustes
% fornecidos pela pesquisadora, garantindo coer�ncia com os
% objetivos e crit�rios do estudo.
%
% A coautoria simb�lica das IAs � reconhecida no aspecto t�cnico,
% sem implicar autoria cient�fica ou responsabilidade intelectual.
% 
% Resposit�rio (em desenvolvimento) de suporte did�tico por IA para 
% conte�dos relacionados ao processamento de dados em:
% https://github.com/htakanaca/AI-Assisted-Learning
% ------------------------------------------------------------
%
% U-Tide de Codiga (2011):
% Copyright (c) 2017, Daniel L. Codiga � redistribu�do conforme licen�a BSD.
%
% Dados de N�vel do Mar (metros):
% - Frequ�ncia amostral: 5 minutos.
% - Per�odo: 01/01/2020 �s 00:00h a 31/12/2024 �s 23:55h.
% - Colunas: 1  2   3   4  5  6   7
% - Formato: DD,MM,YYYY,HH,MM,SS,N�vel (metros).
%
% ATEN��O: 
% 1) Sobre o caminho e formato dos dados:
% Defina o caminho dos seus dados na vari�vel abaixo "data_dir". Os dados
% devem estar no formato definido acima.
%
% 2) Sobre o formato das lacunas de dados:
% Os dados faltantes devem estar preenchidos com NaN!
% => se as falhas amostrais estiverem SEM DADO na coluna 7 (ou em toda a
% linha), vai dar ERRO.
% => se as falhas amostrais estiverem preenchidas com 0 na coluna 7 (ou em 
% toda a linha), vai dar ERRO.
%
% 3) Sobre o uso do U-Tide:
% Os arquivos do U-Tide devem estar de acordo com UMA das op��es:
% a) na mesma pasta em que for executar este script
% b) salvo no PATH do Matlab

clear
clc

%% Abertura e Organiza��o dos dados

% === CONFIGURA��O DO USU�RIO ===
% Defina aqui o nome do arquivo onde est�o os dados originais, que
% ainda cont�m falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc

% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diret�rio onde o script est� localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diret�rio de dados em rela��o � pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);

% Verifica se o arquivo existe antes de carregar
if exist(arquivo, 'file') ~= 2
    error(['\n\n' ...
           '******************************\n' ...
           '***       ATEN��O!         ***\n' ...
           '******************************\n' ...
           '\n' ...
           'ARQUIVO N�O ENCONTRADO!\n\n' ...
           'Verifique se o diret�rio est� correto:\n  %s\n\n' ...
           'E se o nome do arquivo est� correto:\n  %s\n\n'], ...
           data_dir, nome_arquivo);
end

[~, ~, ext] = fileparts(arquivo);

switch lower(ext)
    case '.mat'
        % === ATEN��O: ===
        % Este comando carrega a **primeira vari�vel** do arquivo .mat:
        vars = whos('-file', arquivo);
        if isempty(vars)
            error('Arquivo MAT n�o cont�m vari�veis.');
        end
        nome_var = vars(1).name;  % <-- Aqui pega automaticamente a 1� vari�vel!
        
        % => Garanta que essa vari�vel seja a que cont�m os dados no formato:
        % DD,MM,YYYY,HH,MM,SS,N�vel (metros)
        % Caso n�o seja, altere 'vars(1).name' para o nome correto da vari�vel.
        
        load(arquivo, nome_var);
        dados = eval(nome_var);
        clear(nome_var);
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz num�rica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo n�o suportado.');
end



% Verifica��o do formato dos dados lidos:
% Checa se dados tem pelo menos 7 colunas
if size(dados,2) < 7
    error(['O vetor de dados deve ter pelo menos 7 colunas com o formato:\n' ...
           'DD,MM,YYYY,HH,MM,SS,N�vel (metros).\n' ...
           'Verifique seu arquivo de entrada.']);
end

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

%% Defini��o de par�metros e vari�veis

% Vetor temporal total (base de refer�ncia):
tempo_total_vetorial = 1:tamanho_tempo_total;

% Identifica��o dos blocos de NaN (falhas amostrais) para fazer o 
% preenchimento harm�nico de mar� posteriormente:

% Identifica posi��es com dados faltantes (NaN) no n�vel do mar:
marca_nan=isnan(dados(:,7));

% Adiciona um zero no final para facilitar a detec��o de bordas de blocos 
% de NaN e evitar erro no c�lculo de diferen�as, garantindo vetor como 
% linha:
marca_nan(end+1)=0;
marca_nan=marca_nan';

% Calcula a diferen�a entre elementos consecutivos para identificar 
% transi��es:
% Onde diff = 1, come�a uma falha; onde diff = -1, termina.
diff_marca_nan(1:length(marca_nan))=zeros;
diff_marca_nan(2:end)=diff(marca_nan);

% Ajuste para garantir que o primeiro elemento do vetor de diferen�as 
% esteja corretamente inicializado:
% (Se a s�rie come�a com dado (e n�o NaN), � 0)
diff_marca_nan(1)=0;

% Localiza os �ndices onde come�am os blocos de NaNs (falhas):
% O preenchimento do vetor ini_nan_index_global come�a a partir da posi��o 
% 2, para evitar erros se a s�rie come�ar com NaN.
xx=find(diff_marca_nan==1);
ini_nan_index_global(2:length(xx)+1)=xx;

%  Identifica os �ndices finais das falhas, ajustando para referenciar o 
% �ltimo �ndice de NaN antes do retorno aos dados v�lidos:
xx=find(diff_marca_nan==-1);
fim_nan_index_global(2:length(xx)+1)=xx-1;

%Calcula a dura��o de cada bloco de NaN (lacuna) detectada:
duracao_nan_index_global=fim_nan_index_global-ini_nan_index_global;

% Extrai a s�rie de n�vel do mar original, da coluna 7, para uma vari�vel 
% direta:
nivel_adcp=dados(:,7);

%% Preenchimento Harm�nico com Previs�o de Mar� com o U-Tide (Codiga,2011)

% Loop para preencher cada lacuna identificada:
for ii=2:length(duracao_nan_index_global)
    
    % Define o per�odo de dados que ser� usado como dados de an�lise no 
    % U-Tide, que corresponde ao in�cio (1� dado): at� dado imediatamente 
    % anterior � lacuna:
    data_fim_analise_utide=dados(ini_nan_index_global(ii)-1,1:6);
    
    % Gera vetor de tempo (em formato datenum) para a an�lise harm�nica:
    clear vetor_tempo_analise
    for kk=1:ini_nan_index_global(ii)-1
        vetor_tempo_analise(kk)=datenum(dados(kk,3),dados(kk,2),dados(kk,1),dados(kk,4),dados(kk,5),dados(kk,6));
    end
    
    % Estima coeficientes harm�nicos de mar� com U-Tide:
    clear coef
    coef = ut_solv ( vetor_tempo_analise', nivel_adcp(1:ini_nan_index_global(ii)-1),[], -22.8219,'auto');
    
    % Define o per�odo de previs�o de mar� - desde o in�cio at� o fim da lacuna:
    contatt=1;
    clear vetor_tempo_previsao
    for kk=ini_nan_index_global(ii):fim_nan_index_global(ii)
        vetor_tempo_previsao(contatt)=datenum(dados(kk,3),dados(kk,2),dados(kk,1),dados(kk,4),dados(kk,5),dados(kk,6));
        contatt=contatt+1;
    end
    
    % Reconstr�i a previs�o de mar� com U-Tide:
    [ previsao, ~] = ut_reconstr ( vetor_tempo_previsao', coef );
    
    % Ajuste de offset - m�dia entre valores antes e depois da lacuna:
    nivel_antes=nivel_adcp(ini_nan_index_global(ii)-1);
    nivel_depois=nivel_adcp(fim_nan_index_global(ii)+1);
   
    media_prepos_lacuna = (nivel_antes + nivel_depois) / 2;
    media_previsao = mean(previsao);  % centro da previs�o
    offset = media_prepos_lacuna - media_previsao;
    
    % Aplica o ajuste de offset � previs�o:
    previsao_ajustada = previsao + offset;
    
    % Substitui a lacuna na s�rie original pela previs�o ajustada:
    nivel_adcp(ini_nan_index_global(ii):fim_nan_index_global(ii)) = previsao_ajustada;
    
    % Mensagem indicativa de preenchimento realizado:
%     disp(['Preenchimento Harm�nico de Mar� de ', num2str(ini_nan_index_global(ii)), ' a ', num2str(fim_nan_index_global(ii)), ' (offset direto aplicado)'])
    fprintf('Preenchimento Harm�nico de Mar� de %d a %d (offset direto aplicado)\n', ...
        ini_nan_index_global(ii), fim_nan_index_global(ii));
        
end

%% Salva as vari�veis

% Formato .mat:
nivel_adcp_comtide=nivel_adcp;
nivel_adcp=dados(:,7);

save ('nivel_adcp_comtide.mat','nivel_adcp_comtide');

% Formato .csv:
dados_preenchidos = dados(1:tamanho_tempo_total,1:6);
dados_preenchidos(:,7) = nivel_adcp_comtide;

% Sem cabe�alho:
% dlmwrite('nivel_adcp_comtide.csv', dados_preenchidos, 'delimiter', ',', 'precision', 6);

filename = 'nivel_adcp_comtide.csv';
fid = fopen(filename, 'w');

% Escreve o cabe�alho
fprintf(fid, 'DD;MM;YYYY;HH;MM;SS;Nivel(m)\n');

% Escreve os dados com separador ';' e 4 casas decimais
for i = 1:size(dados_preenchidos,1)
    fprintf(fid, '%02d;%02d;%04d;%02d;%02d;%02d;%.4f\n', ...
        dados_preenchidos(i,1), dados_preenchidos(i,2), dados_preenchidos(i,3), ...
        dados_preenchidos(i,4), dados_preenchidos(i,5), dados_preenchidos(i,6), ...
        dados_preenchidos(i,7));
end

fclose(fid);

