# Patrulha Conectada

## Descrição
O **Patrulha Conectada** é um aplicativo móvel desenvolvido em Flutter que permite a monitorização em tempo real da localização de viaturas policiais. A aplicação utiliza serviços de geolocalização e integração com o Firebase para fornecer uma solução robusta e escalável para equipes de segurança pública.

## Funcionalidades

- **Autenticação Segura**: Sistema de login e cadastro com gerenciamento de usuários no Firebase Authentication.
- **Mapa Interativo**: Visualização em tempo real das posições das viaturas usando o Google Maps.
- **Atualizações em Tempo Real**: Localizações atualizadas constantemente via Firestore.
- **Gerenciamento de Estado**: Utilização do Riverpod para gerenciamento reativo do estado da aplicação.
- **Serviço em Background**: Funcionalidade de atualização de localização mesmo com o aplicativo minimizado.
- **Interface Responsiva**: Design adaptável para diferentes tamanhos de tela.

## Tecnologias Utilizadas

- **Flutter**: Framework de desenvolvimento cross-platform.
- **Firebase**: Serviços de autenticação, banco de dados em tempo real (Firestore) e armazenamento.
- **Google Maps Flutter**: Integração com mapas interativos.
- **Riverpod**: Gerenciamento de estado reativo.
- **Geolocator**: Acesso à localização do dispositivo.
- **SharedPreferences**: Armazenamento local de dados simples.

## Estrutura do Projeto

```
lib/
├── application/
│   ├── providers/          # Providers do Riverpod
│   └── services/           # Serviços da aplicação
├── data/
│   ├── data_sources/       # Fontes de dados (Firestore, Local)
│   ├── models/             # Modelos de dados
│   └── repositories/       # Repositórios para abstração de dados
├── presentation/
│   ├── screens/            # Telas do aplicativo
│   └── widgets/            # Widgets reutilizáveis
├── main.dart               # Ponto de entrada da aplicação
└── firebase_options.dart   # Configurações do Firebase
```

## Como Executar Localmente

1. **Requisitos**:
   - Flutter instalado e configurado
   - Conta do Google para APIs (para habilitar o Google Maps)
   - Conta do Firebase

2. **Configuração**:
   - Clone este repositório
   - Execute `flutter pub get` para instalar as dependências
   - Configure suas credenciais do Firebase em `firebase_options.dart`
   - Configure sua chave da API do Google Maps no arquivo apropriado

3. **Execução**:
   - Execute o aplicativo em um dispositivo móvel ou emulador com o comando `flutter run`

## Contribuindo

Contribuições são bem-vindas! Por favor, leia o `CONTRIBUTING.md` para detalhes sobre como submeter issues, pull requests ou melhorias.

## Licença

Este projeto está licenciado sob a MIT License - veja o arquivo `LICENSE` para mais detalhes.
