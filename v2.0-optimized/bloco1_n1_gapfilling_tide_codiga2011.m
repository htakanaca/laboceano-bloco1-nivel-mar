%
% Versão: 2.0-Optmized
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
% 
% Respositório (em desenvolvimento) de suporte didático por IA para 
% conteúdos relacionados ao processamento de dados em:
% https://github.com/htakanaca/AI-Assisted-Learning
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

filename_output_csv = 'nivel_adcp_comtide.csv';

filename_output_mat = './Dados/nivel_adcp_comtide.mat';

% === FIM DA CONFIGURAÇÃO DO USUÁRIO ===

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
           data_dir, nomedoarquivo);
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
        
        % Otimização: Carrega para uma struct e acessa o campo
        data_struct = load(arquivo, nome_var);
        dados = data_struct.(nome_var); % Acessa a variável pelo nome
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

%% Definição de parâmetros e variáveis

% Latitude do local:
latitude_local = -22.8219;

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Assumindo que a ordem em "dados" é DD,MM,YYYY,HH,MM,SS
datas_dn = datenum(dados(:,3), dados(:,2), dados(:,1), ... % YYYY,MM,DD
                   dados(:,4), dados(:,5), dados(:,6));    % HH,MM,SS

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
    
    % O período de dados que será usado como dados de análise no U-Tide, 
    % que corresponde ao início (1º dado) até o dado imediatamente 
    % anterior à lacuna. Gera vetor de tempo (em formato datenum) para a 
    % análise harmônica:
    
    % Estima coeficientes harmônicos de maré com U-Tide:
    coef = ut_solv(datas_dn(1:ini_nan_index_global(ii)-1),...
        nivel_adcp(1:ini_nan_index_global(ii)-1),[],latitude_local,'auto');
    
    % Reconstrói a previsão de maré com U-Tide:
    [ previsao, ~] = ut_reconstr(datas_dn(ini_nan_index_global(ii):fim_nan_index_global(ii)),coef);
    
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
    fprintf('Preenchimento Harmônico de Maré de %d a %d (offset direto aplicado)\n', ...
        ini_nan_index_global(ii), fim_nan_index_global(ii));
        
end

%% Salva as variáveis

% Formato .mat:
fprintf('Salvando arquivo MAT...\n')

nivel_adcp_comtide=nivel_adcp;
nivel_adcp=dados(:,7);

save (filename_output_mat,'nivel_adcp_comtide');

% Formato .csv:
fprintf('Salvando arquivo CSV...\n')

dados_preenchidos = dados(1:tamanho_tempo_total,1:6);
dados_preenchidos(:,7) = nivel_adcp_comtide;

% Assumindo que 'dados_preenchidos' é uma matriz numérica de 7 colunas
% [DD,MO,YYYY,HH,MM,SS,Nivel(m)]

% Crie uma tabela a partir da sua matriz para aproveitar o writetable
% E defina os nomes das colunas (cabeçalho)
T = array2table(dados_preenchidos, 'VariableNames', {'DD','MO','YYYY','HH','MM','SS','Nivel_m'});

% Salva a tabela no formato CSV:
writetable(T, filename_output_csv, ...
    'Delimiter', ';', ... % Seu delimitador é ponto e vírgula
    'WriteVariableNames', true, ... % Escreve os nomes das variáveis (cabeçalho)
    'QuoteStrings', false, ... % Evita aspas em volta dos números, se não forem strings
    'FileType', 'text'); % Especifica que é um arquivo de texto

fprintf('Feito!\n')
