// What /profile answers, from the profile command's results; pure, for the tests.

export type Run = { exitCode: number; stdout: string; stderr: string }

export type Profile = { name: string; description: string; isCurrent: boolean; isDefault: boolean; isProject: boolean }

// The profiles of `claude-profile list`: `* name   description [state]`, `*` on the session's,
// `par défaut` in the state of the default one (`reference`, the reference profile, when none is set),
// `projet` in that of the current project's.
export const parseList = (stdout: string): Profile[] =>
  stdout.split('\n').flatMap(line => {
    const m = /^([* ]) (\S+)\s*(.*?)\s*(\[[^\]]*\])?$/.exec(line)
    const state = m?.[4] ?? ''
    return m?.[2]
      ? [{ name: m[2], description: m[3] ?? '', isCurrent: m[1] === '*', isDefault: /par défaut/.test(state), isProject: /projet/.test(state) }]
      : []
  })

export const HINT =
  '\n/profile <profil> : relance cette conversation dans ce profil.\n/profile show [<profil>] : ce qui y est actif, ses plugins et MCP à (dés)activer ; /profile create <nom> : nouveau profil ; /profile default [<profil>] : profil par défaut des nouvelles sessions ; /profile project [<profil>|--unset] : profil des nouvelles sessions de ce projet ; /profile reference : revenir au settings.json de référence.'

// Relaunch by hand, for a session no `claude-profile switch`/`run` loop started.
export const manual = (name: string) =>
  `Cette session n'a pas été lancée par claude-profile switch/run (ni par la fonction shell claude) : ` +
  `relance manuelle. /exit, puis dans ce dossier : claude-profile switch ${name} --continue`

// The answer to `/profile <name>` once `claude-profile request` ran: `exit` when the
// loop will relaunch the session, `isBackground` for a background session (request left,
// the session to stop first), then the text to show.
export function afterRequest(name: string, req: Run): { exit: boolean; isBackground: boolean; text: string } {
  if (req.exitCode === 0) return { exit: true, isBackground: false, text: `Bascule vers le profil ${name} : la session se relance…` }
  if (req.exitCode === 3) return { exit: false, isBackground: false, text: manual(name) }
  const text = req.stderr.trim() || `claude-profile request a échoué (code ${req.exitCode})`
  return { exit: false, isBackground: req.exitCode === 4, text }
}

// One line of `claude-profile show`: under `plugins :` (or `plugins de la base :`, those of a
// profile's base), a plugin (`+` on, `-` off, `?`
// installed but not in the profile, so off); under `MCP :`, a server (`+` on, `-` cut; its
// name may hold spaces, its notes in parentheses follow); any other line, as text.
export type ShowLine =
  | { plugin: string; isOn: boolean; isListed: boolean }
  | { mcp: string; isOn: boolean; note: string }
  | { text: string }

export function parseShow(stdout: string): ShowLine[] {
  let section = ''
  return stdout.trimEnd().split('\n').map(line => {
    if (!line.startsWith('  ')) section = line
    if (section === 'MCP :') {
      const m = /^ {2}([+-]) (.+?)((?: \([^()]*\))*)$/.exec(line)
      if (m?.[2]) return { mcp: m[2], isOn: m[1] === '+', note: m[3]?.trim() ?? '' }
    }
    const m = /^ {2}([+?-]) (\S+)/.exec(line)
    return /^plugins( de la base)? :$/.test(section) && m?.[2] ? { plugin: m[2], isOn: m[1] === '+', isListed: m[1] !== '?' } : { text: line }
  })
}

// The draft key of a show line: the plugin, or `mcp:` and the server.
export const draftKey = (line: { plugin: string } | { mcp: string }) => ('plugin' in line ? line.plugin : `mcp:${line.mcp}`)

// A draft (draft key → wanted state) with `plugin` (a draft key) flipped from `isOn`, its
// shown state: flipping it back drops it, so the draft holds only real changes.
export function toggleDraft(draft: Record<string, boolean>, plugin: string, isOn: boolean): Record<string, boolean> {
  const { [plugin]: was, ...rest } = draft
  return was === undefined ? { ...draft, [plugin]: !isOn } : rest
}

// The `claude-profile plugin|mcp <profil> <name> on|off` calls a draft comes to, against what
// `show` says: the action, the name, the state.
export const draftChanges = (lines: ShowLine[], draft: Record<string, boolean>) =>
  lines.flatMap(line => {
    if ('text' in line) return []
    const wanted = draft[draftKey(line)]
    if (wanted === undefined || wanted === line.isOn) return []
    return [{ action: 'plugin' in line ? 'plugin' : 'mcp', name: 'plugin' in line ? line.plugin : line.mcp, state: wanted ? 'on' : 'off' }]
  })
