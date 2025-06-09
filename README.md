# LabOceano :: Bloco 1 :: Nível do Mar Scripts de Processamento
## Dados de Nível do Mar de ADCP na Baía de Guanabara.

Este repositório contém os scripts utilizados para o preenchimento de falhas amostrais nos dados de nível do mar obtidos por ADCP da Bóia BH07, localizada na Baía de Guanabara. O método de preenchimento emprega previsão harmônica de maré utilizando o pacote U-Tide (Codiga, 2011) e, posteriormente, aplica suavização de offsets gerados pela previsão e substituição de outliers.

---

## Estrutura do Repositório

* `v1.0-original/`: Scripts MATLAB para análise e processamento dos dados de nível do mar, versão original, sem otimizações e melhorias.
* `v1.0-original/Dados`: Pasta para o usuário colocar os dados a serem processados.
* `v2.0-original/`: (Recomendada) - Em construção - Versão otimizada e com melhorias da versão 1.0-original.
* `v2.0-original/Dados`: Pasta para o usuário colocar os dados a serem processados.
* `U-TIDE/`: Scripts do pacote U-Tide de Codiga (2011), necessários em cada versão do repositório (1.0, 2.0).
* `U-TIDE/LICENSE`: Termos de licença do pacote U-Tide.

**Importante:** Os dados originais utilizados neste estudo não estão disponibilizados neste repositório por questões legais e de confidencialidade.

---

## Ferramentas e Métodos

* **MATLAB**: Desenvolvimento e execução dos scripts.
* **U-Tide**: Pacote MATLAB para análise harmônica de maré (Codiga, 2011).
* **Processamento**: Identificação automática de falhas amostrais (`NaN`), preenchimento por previsão harmônica ajustada com correção de offset, suavização de offsets restantes e substituição de outliers por média simples dos vizinhos.

---

## Autoria e Reconhecimento

* **Desenvolvido por**: Hatsue Takanaca de Decco
* **Contato**: takanaca@gmail.com

**Apoio Técnico de Inteligência Artificial:**
Este trabalho foi significativamente auxiliado por modelos de inteligência artificial durante o processo de desenvolvimento e otimização dos scripts. As IAs contribuíram com sugestões de código, explicações de conceitos de programação e otimização, e refatoração de trechos específicos.

As seguintes IAs foram consultadas e forneceram suporte técnico:
* **ChatGPT** (OpenAI): Consultoria e suporte técnico em maio de 2025.
* **Grok** (xAI): Consultoria e suporte técnico em maio de 2025.
* **Gemini** (Google AI): Consultoria e suporte técnico em junho de 2025.  
  Repositório de suporte didático (em desenvolvimento) por IA em: https://github.com/htakanaca/AI-Assisted-Learning

Reconhecemos a contribuição dessas ferramentas como um **apoio técnico** valioso na codificação e na compreensão de algoritmos, sem que isso implique autoria científica, responsabilidade intelectual ou endosso do conteúdo científico final por parte das IAs ou de suas desenvolvedoras. A autoria e a responsabilidade pelo conteúdo e resultados permanecem integralmente com a pesquisadora.

---

## Licença

Este repositório inclui scripts que utilizam o pacote U-Tide, distribuído sob a licença BSD. Consulte o arquivo `LICENSE` para mais informações.

---

## Link

https://github.com/htakanaca/laboceano-bloco1-nivel-mar
