// What /profile answers, from the profile command's results; pure, for the tests.

export type Run = { exitCode: number; stdout: string; stderr: string }

export type Profile = { name: string; description: string; isCurrent: boolean; isDefault: boolean }

// The profiles of `claude-profile list`: `* name   description [state]`, `*` on the session's,
// `par défaut` in the state of the default one (`reference`, the reference profile, when none is set).
export const parseList = (stdout: string): Profile[] =>
  stdout.split('\n').flatMap(line => {
    const m = /^([* ]) (\S+)\s*(.*?)\s*(\[[^\]]*\])?$/.exec(line)
    return m?.[2] ? [{ name: m[2], description: m[3] ?? '', isCurrent: m[1] === '*', isDefault: /par défaut/.test(m[4] ?? '') }] : []
  })

export const HINT =
  '\n/profile <profil> : relance cette conversation dans ce profil.\n/profile show [<profil>] : ce qui y est actif, ses plugins à (dés)activer ; /profile create <nom> : nouveau profil ; /profile default [<profil>] : profil par défaut des nouvelles sessions ; /profile reference : revenir au settings.json de référence.'

// Relaunch by hand, for a session no `claude-profile switch`/`run` loop started.
export const manual = (name: string) =>
  `Cette session n'a pas été lancée par claude-profile switch/run (ni par la fonction shell claude) : ` +
  `relance manuelle. /exit, puis dans ce dossier : claude-profile switch ${name} --continue`

// The answer to `/profile <name>` once `claude-profile request` ran: `exit` when the
// loop will relaunch the session, then the text to show.
export function afterRequest(name: string, req: Run): { exit: boolean; text: string } {
  if (req.exitCode === 0) return { exit: true, text: `Bascule vers le profil ${name} : la session se relance…` }
  if (req.exitCode === 3) return { exit: false, text: manual(name) }
  return { exit: false, text: req.stderr.trim() || `claude-profile request a échoué (code ${req.exitCode})` }
}

// One line of `claude-profile show`: a plugin (`+` on, `-` off, `?` installed but not in
// the profile, so off) or any other line, as text.
export type ShowLine = { plugin: string; isOn: boolean; isListed: boolean } | { text: string }

export const parseShow = (stdout: string): ShowLine[] =>
  stdout.trimEnd().split('\n').map(line => {
    const m = /^ {2}([+?-]) (\S+)/.exec(line)
    return m?.[2] ? { plugin: m[2], isOn: m[1] === '+', isListed: m[1] !== '?' } : { text: line }
  })

// A draft (plugin → wanted state) with `plugin` flipped from `isOn`, its shown state:
// flipping it back drops it, so the draft holds only real changes.
export function toggleDraft(draft: Record<string, boolean>, plugin: string, isOn: boolean): Record<string, boolean> {
  const { [plugin]: was, ...rest } = draft
  return was === undefined ? { ...draft, [plugin]: !isOn } : rest
}

// The `claude-profile plugin` calls a draft comes to, against what `show` says.
export const draftChanges = (lines: ShowLine[], draft: Record<string, boolean>) =>
  lines.flatMap(line =>
    'plugin' in line && draft[line.plugin] !== undefined && draft[line.plugin] !== line.isOn
      ? [{ plugin: line.plugin, state: draft[line.plugin] ? 'on' : 'off' }]
      : [],
  )
