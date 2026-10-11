import Foundation

/// The language the planner shows. "Same as Mac" follows the system's preferred language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, portuguese
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return tr("Same as Mac")
        case .english: return "English"
        case .portuguese: return "Português"
        }
    }
}

enum Lang {
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
    }

    static var isPortuguese: Bool {
        switch current {
        case .portuguese: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") ?? false
        }
    }
}

/// Every string is written in English in the code; this returns the Portuguese version when needed.
func tr(_ english: String) -> String {
    Lang.isPortuguese ? (portuguese[english] ?? english) : english
}

private let portuguese: [String: String] = [
    // Items
    "Task": "Tarefa",
    "Meeting": "Reunião",
    "Reminder": "Lembrete",
    "What needs to be done?": "O que precisa ser feito?",
    "Meeting name": "Nome da reunião",
    "What to remember?": "O que lembrar?",
    "Water": "Água",
    "Workout": "Treino",
    "Reading": "Leitura",

    // Settings and menus
    "On the desktop, behind windows": "Na mesa, atrás das janelas",
    "Normal window": "Janela normal",
    "Always on top": "Sempre por cima",
    "Horizontal (days in columns)": "Horizontal (dias em colunas)",
    "Vertical (days in rows)": "Vertical (dias em linhas)",
    "Small": "Pequeno",
    "Default": "Padrão",
    "Large": "Grande",
    "Larger": "Maior",
    "Same as Mac": "Igual ao Mac",
    "Language": "Idioma",
    "Layout": "Layout",
    "Position on screen": "Posição na tela",
    "Text size": "Tamanho do texto",
    "Open at login": "Abrir ao ligar o Mac",
    "Show": "Mostrar",
    "Weekly progress": "Progresso da semana",
    "Focus minutes per day": "Minutos de foco por dia",
    "Weekly priorities": "Prioridades da semana",
    "Daily habits": "Hábitos diários",
    "About Planner": "Sobre o Planner",
    "Created by Victor Tognollo\nLicense: free forever": "Criado por Victor Tognollo\nLicença: gratuito para sempre",
    "Quit Planner": "Sair do Planner",
    "Settings": "Ajustes",
    "Edit": "Editar",
    "Undo": "Desfazer",
    "Redo": "Refazer",
    "Cut": "Recortar",
    "Copy": "Copiar",
    "Paste": "Colar",
    "Select All": "Selecionar tudo",

    // Header
    "Previous week": "Semana anterior",
    "Next week": "Próxima semana",
    "Today": "Hoje",
    "Priorities": "Prioridades",
    "1st": "1ª",
    "2nd": "2ª",
    "3rd": "3ª",

    // Days and items
    "Add item": "Adicionar item",
    "Add or edit habits": "Incluir ou editar hábitos",
    "Join": "Entrar",
    "Delete": "Apagar",
    "Mark as done": "Concluir",
    "Mark as not done": "Desmarcar",
    "Move to tomorrow": "Mover para amanhã",
    "New item": "Novo item",
    "Edit item": "Editar item",
    "Type": "Tipo",
    "Time": "Horário",
    "Cancel": "Cancelar",
    "Add": "Adicionar",
    "Save": "Salvar",
    "Your habits": "Seus hábitos",
    "apply to every day": "valem para todos os dias",
    "No habits yet. Add your first one below.": "Nenhum hábito ainda. Inclua o primeiro abaixo.",
    "New habit, e.g. Meditate": "Novo hábito, ex.: Meditar",
    "Habit": "Hábito",

    // Focus timer
    "FOCUS": "FOCO",
    "Ready": "Pronto",
    "Focusing": "Focando",
    "Paused": "Pausado",
    "Done": "Concluído",
    "Start": "Iniciar",
    "Pause": "Pausar",
    "Reset": "Zerar",
    "Custom minutes (1–180). Press Return to start.": "Minutos personalizados (1 a 180). Enter começa.",

    // Notifications
    "Meeting in 5 minutes": "Reunião em 5 minutos",
    "Focus session done": "Foco concluído",

    // Calendars
    "Untitled": "Sem título",
    "All day": "Dia todo",
    "Open in Calendar": "Abrir no Calendário",
    "Synced calendars": "Agendas sincronizadas",
    "Calendars": "Agendas",
    "Sync with your Mac calendars": "Sincronizar com as agendas do Mac",
    "Planner can't access your calendars. Allow it in System Settings > Privacy & Security > Calendars.":
        "O Planner não tem acesso ao Calendário. Libere em Ajustes do Sistema > Privacidade e Segurança > Calendários.",
    "Open Settings": "Abrir Ajustes",
    "No calendars on this Mac yet. Add one below.": "Nenhuma agenda no Calendário do Mac ainda. Adicione uma abaixo.",
    "Add a calendar": "Adicionar agenda",
    "Google, Outlook or iCloud account…": "Conta Google, Outlook ou iCloud…",
    "In Internet Accounts, sign in and turn on Calendars.": "Em Contas de Internet, entre na conta e ligue Calendários.",
    "Calendar link from any website (.ics)": "Link de agenda de qualquer site (.ics)",
    "https://…/calendar.ics": "https://…/agenda.ics",
    "Subscribe": "Assinar",
    "Calendar opened to confirm. The events will show up here afterwards.":
        "O Calendário do Mac abriu para confirmar. Depois os eventos aparecem aqui.",
    "Calendar opens to confirm, then keeps it up to date.":
        "O Calendário do Mac abre para confirmar e passa a atualizar sozinho.",
]
