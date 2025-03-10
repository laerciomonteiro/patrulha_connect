## Como Contribuir para o Patrulha Conectada

Obrigado por considerar contribuir para o Patrulha Conectada! Sua contribuição é valorosa e ajudará a melhorar a aplicação para todos os usuários.

## Configurando o Ambiente de Desenvolvimento

1. **Requisitos Pré-requisitos**:
   - Instale o [Flutter](https://flutter.dev/docs/get-started/install)
   - Configure suas variáveis de ambiente para o Flutter
   - Instale uma IDE compatível (VS Code ou Android Studio recomendados)

2. **Clonando o Repositório**:
   ```bash
   git clone https://github.com/seu-usuario/patrulha-conectada.git
   cd patrulha-conectada
   ```

3. **Instalando Dependências**:
   ```bash
   flutter pub get
   ```

4. **Configurando o Firebase**:
   - Crie um projeto no [Console do Firebase](https://console.firebase.google.com/)
   - Adicione suas credenciais do Firebase em `lib/firebase_options.dart`
   - Configure o Google Maps API para sua aplicação

## Fluxo de Trabalho de Contribuição

1. **Crie um Fork do Projeto**:
   - Clique no botão "Fork" no repositório original para criar uma cópia no seu GitHub.

2. **Clone Seu Fork Localmente**:
   ```bash
   git clone https://github.com/seu-usuario/patrulha-conectada.git
   cd patrulha-conectada
   git remote add upstream https://github.com/original-usuario/patrulha-conectada.git
   ```

3. **Crie uma Branch para Sua Feature ou Correção**:
   ```bash
   git checkout -b nome-da-sua-feature
   ```

4. **Faça suas Alterações**:
   - Mantenha seu código limpo e organizado
   - Adicione comentários explicativos quando necessário
   - Atualize a documentação se necessário

5. **Faça Commit das Alterações**:
   ```bash
   git add .
   git commit -m "Descreva suas alterações aqui"
   ```

6. **Faça Push para Seu Fork**:
   ```bash
   git push origin nome-da-sua-feature
   ```

7. **Crie uma Pull Request**:
   - Vá para seu fork no GitHub
   - Clique em "New Pull Request"
   - Preencha os detalhes da sua contribuição
   - Envie para revisão

## Diretrizes de Código

- **Estilo de Código**: Siga as [diretrizes de estilo do Dart](https://dart.dev/guides/language/effective-dart)
- **Comentários**: Adicione comentários explicando partes complexas do código
- **Testes**: Adicione testes unitários e de integração quando possível
- **Commit Messages**: Use mensagens descritivas para commits

## Enviando Issues

- **Antes de Abrir um Issue**: Verifique se o problema já foi reportado
- **Descreva o Problema**: Forneça detalhes sobre como reproduzir o problema
- **Inclua Informações do Ambiente**: Versão do Flutter, dispositivo, sistema operacional
- **Proposta de Solução**: Se possível, sugira uma solução ou correção

## Documentação

- Mantenha a documentação atualizada com suas alterações
- Adicione comentários no código para explicar funcionalidades complexas
- Atualize o README.md quando necessário

## Licença

Ao contribuir para este projeto, você concorda que suas contribuições estão sob a mesma licença do projeto (MIT License).
