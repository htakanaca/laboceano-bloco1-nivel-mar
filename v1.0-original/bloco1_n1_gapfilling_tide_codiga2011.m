%
% Bloco 1 - Scripts de Processamento LabOceano
%
% Passo 1: Preenchimento de Falhas Amostrais com Previsão de Maré
%
% Aplicação: Dados de NÌVEL DO MAR de ADCP da Bóia BH07, na Baía de 
% Guanabara.
%
% Utiliza-se o pacote U-Tide de Codiga (2011) para preencher as falhas 
% com previsão de maré.
%
% Hatsue Takanaca de Decco, Abril/2025.
%
% Contribuições de IA: 
% ------------------------------------------------------------
% Este script foi desenvolvido com o auxílio das inteligências
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio de 2025,
% e Gemini (Gooogle AI) em junho de 2025. 
% A lógica foi construída a partir de instruções e ajustes
% fornecidos pela pesquisadora, garantindo coerência com os
% objetivos e critérios do estudo.
%
% A coautoria simbólica das IAs é reconhecida no aspecto técnico,
% sem implicar autoria científica ou responsabilidade intelectual.
% ------------------------------------------------------------
%
% U-Tide de Codiga (2011):
% Copyright (c) 2017, Daniel L. Codiga — redistribuído conforme licença BSD.
%
% Dados de Nível do Mar (metros):
% - Frequência amostral: 5 minutos.
% - Período: 01/01/2020 às 00:00h a 31/12/2024 às 23:55h.
% - Colunas: 1  2   3   4  5  6   7
% - Formato: DD,MM,YYYY,HH,MM,SS,Nível (metros).
%
% ATENÇÃO: 
% 1) Sobre o caminho e formato dos dados:
% Defina o caminho dos seus dados na variável abaixo "data_dir". Os dados
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
% Os arquivos do U-Tide devem estar de acordo com UMA das opções:
% a) na mesma pasta em que for executar este script
% b) salvo no PATH do Matlab

clear
clc

%% Abertura e Organização dos dados

% === CONFIGURAÇÃO DO USUÁRIO ===
% Defina aqui o nome do arquivo onde estão os dados originais, que
% ainda contém falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_nivel.txt'; % .mat, .txt, etc

% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diretório onde o script está localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diretório de dados em relação à pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);

% Verifica se o arquivo existe antes de carregar
if exist(arquivo, 'file') ~= 2
    error(['\n\n' ...
           '******************************\n' ...
           '***       ATENÇÃO!         ***\n' ...
           '******************************\n' ...
           '\n' ...
           'ARQUIVO NÃO ENCONTRADO!\n\n' ...
           'Verifique se o diretório está correto:\n  %s\n\n' ...
           'E se o nome do arquivo está correto:\n  %s\n\n'], ...
           data_dir, nome_arquivo);
end

[~, ~, ext] = fileparts(arquivo);

switch lower(ext)
    case '.mat'
        % === ATENÇÃO: ===
        % Este comando carrega a **primeira variável** do arquivo .mat:
        vars = whos('-file', arquivo);
        if isempty(vars)
            error('Arquivo MAT não contém variáveis.');
        end
        nome_var = vars(1).name;  % <-- Aqui pega automaticamente a 1ª variável!
        
        % => Garanta que essa variável seja a que contém os dados no formato:
        % DD,MM,YYYY,HH,MM,SS,Nível (metros)
        % Caso não seja, altere 'vars(1).name' para o nome correto da variável.
        
        load(arquivo, nome_var);
        dados = eval(nome_var);
        clear(nome_var);
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz numérica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo não suportado.');
end



% Verificação do formato dos dados lidos:
% Checa se dados tem pelo menos 7 colunas
if size(dados,2) < 7
    error(['O vetor de dados deve ter pelo menos 7 colunas com o formato:\n' ...
           'DD,MM,YYYY,HH,MM,SS,Nível (metros).\n' ...
           'Verifique seu arquivo de entrada.']);
end

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

%% Definição de parâmetros e variáveis

% Vetor temporal total (base de referência):
tempo_total_vetorial = 1:tamanho_tempo_total;

% Identificação dos blocos de NaN (falhas amostrais) para fazer o 
% preenchimento harmônico de maré posteriormente:

% Identifica posições com dados faltantes (NaN) no nível do mar:
marca_nan=isnan(dados(:,7));

% Adiciona um zero no final para facilitar a detecção de bordas de blocos 
% de NaN e evitar erro no cálculo de diferenças, garantindo vetor como 
% linha:
marca_nan(end+1)=0;
marca_nan=marca_nan';

% Calcula a diferença entre elementos consecutivos para identificar 
% transições:
% Onde diff = 1, começa uma falha; onde diff = -1, termina.
diff_marca_nan(1:length(marca_nan))=zeros;
diff_marca_nan(2:end)=diff(marca_nan);

% Ajuste para garantir que o primeiro elemento do vetor de diferenças 
% esteja corretamente inicializado:
% (Se a série começa com dado (e não NaN), é 0)
diff_marca_nan(1)=0;

% Localiza os índices onde começam os blocos de NaNs (falhas):
% O preenchimento do vetor ini_nan_index_global começa a partir da posição 
% 2, para evitar erros se a série começar com NaN.
xx=find(diff_marca_nan==1);
ini_nan_index_global(2:length(xx)+1)=xx;

%  Identifica os índices finais das falhas, ajustando para referenciar o 
% último índice de NaN antes do retorno aos dados válidos:
xx=find(diff_marca_nan==-1);
fim_nan_index_global(2:length(xx)+1)=xx-1;

%Calcula a duração de cada bloco de NaN (lacuna) detectada:
duracao_nan_index_global=fim_nan_index_global-ini_nan_index_global;

% Extrai a série de nível do mar original, da coluna 7, para uma variável 
% direta:
nivel_adcp=dados(:,7);

%% Preenchimento Harmônico com Previsão de Maré com o U-Tide (Codiga,2011)

% Loop para preencher cada lacuna identificada:
for ii=2:length(duracao_nan_index_global)
    
    % Define o período de dados que será usado como dados de análise no 
    % U-Tide, que corresponde ao início (1º dado): até dado imediatamente 
    % anterior à lacuna:
    data_fim_analise_utide=dados(ini_nan_index_global(ii)-1,1:6);
    
    % Gera vetor de tempo (em formato datenum) para a análise harmônica:
    clear vetor_tempo_analise
    for kk=1:ini_nan_index_global(ii)-1
        vetor_tempo_analise(kk)=datenum(dados(kk,3),dados(kk,2),dados(kk,1),dados(kk,4),dados(kk,5),dados(kk,6));
    end
    
    % Estima coeficientes harmônicos de maré com U-Tide:
    clear coef
    coef = ut_solv ( vetor_tempo_analise', nivel_adcp(1:ini_nan_index_global(ii)-1),[], -22.8219,'auto');
    
    % Define o período de previsão de maré - desde o início até o fim da lacuna:
    contatt=1;
    clear vetor_tempo_previsao
    for kk=ini_nan_index_global(ii):fim_nan_index_global(ii)
        vetor_tempo_previsao(contatt)=datenum(dados(kk,3),dados(kk,2),dados(kk,1),dados(kk,4),dados(kk,5),dados(kk,6));
        contatt=contatt+1;
    end
    
    % Reconstrói a previsão de maré com U-Tide:
    [ previsao, ~] = ut_reconstr ( vetor_tempo_previsao', coef );
    
    % Ajuste de offset - média entre valores antes e depois da lacuna:
    nivel_antes=nivel_adcp(ini_nan_index_global(ii)-1);
    nivel_depois=nivel_adcp(fim_nan_index_global(ii)+1);
   
    media_prepos_lacuna = (nivel_antes + nivel_depois) / 2;
    media_previsao = mean(previsao);  % centro da previsão
    offset = media_prepos_lacuna - media_previsao;
    
    % Aplica o ajuste de offset à previsão:
    previsao_ajustada = previsao + offset;
    
    % Substitui a lacuna na série original pela previsão ajustada:
    nivel_adcp(ini_nan_index_global(ii):fim_nan_index_global(ii)) = previsao_ajustada;
    
    % Mensagem indicativa de preenchimento realizado:
%     disp(['Preenchimento Harmônico de Maré de ', num2str(ini_nan_index_global(ii)), ' a ', num2str(fim_nan_index_global(ii)), ' (offset direto aplicado)'])
    fprintf('Preenchimento Harmônico de Maré de %d a %d (offset direto aplicado)\n', ...
        ini_nan_index_global(ii), fim_nan_index_global(ii));
        
end

%% Salva as variáveis

% Formato .mat:
nivel_adcp_comtide=nivel_adcp;
nivel_adcp=dados(:,7);

save ('nivel_adcp_comtide.mat','nivel_adcp_comtide');

% Formato .csv:
dados_preenchidos = dados(1:tamanho_tempo_total,1:6);
dados_preenchidos(:,7) = nivel_adcp_comtide;

% Sem cabeçalho:
% dlmwrite('nivel_adcp_comtide.csv', dados_preenchidos, 'delimiter', ',', 'precision', 6);

filename = 'nivel_adcp_comtide.csv';
fid = fopen(filename, 'w');

% Escreve o cabeçalho
fprintf(fid, 'DD;MM;YYYY;HH;MM;SS;Nivel(m)\n');

% Escreve os dados com separador ';' e 4 casas decimais
for i = 1:size(dados_preenchidos,1)
    fprintf(fid, '%02d;%02d;%04d;%02d;%02d;%02d;%.4f\n', ...
        dados_preenchidos(i,1), dados_preenchidos(i,2), dados_preenchidos(i,3), ...
        dados_preenchidos(i,4), dados_preenchidos(i,5), dados_preenchidos(i,6), ...
        dados_preenchidos(i,7));
end

fclose(fid);

