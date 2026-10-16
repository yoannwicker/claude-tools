import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Draft } from '../types'
import { afterRequest, draftChanges, draftKey, HINT, parseList, parseShow, toggleDraft } from './switch'
import type { Profile } from './switch'

// The dialogs: pick a profile to switch to, to view, or to make the default; one profile's view.
const PICKER = 'profile-picker'
const VIEWER = 'profile-show'
const DEFAULTER = 'profile-default'
const DETAIL = 'profile-show--'
// The drafts of the profile views in edit mode, by profile; each write redraws the views.
const drafts = atom({ plugin: 'profiles', key: 'drafts' } as const, {} as Record<string, Draft>)

// The claude-profile command, this plugin's bin/claude-profile.
function run($: EngineInterface, ...args: string[]) {
  return $.process.run([`${$.plugin.root}/bin/claude-profile`, ...args])
}

async function profiles($: EngineInterface) {
  return parseList((await run($, 'list')).stdout)
}

// Relaunches this conversation in `name`; the text to show.
async function switchTo($: EngineInterface, name: string) {
  const current = (await run($, 'current')).stdout.trim()
  if (name === current) return `Déjà sur le profil ${name}.`
  // Prepared before leaving, so an invalid profile is reported here.
  const generated = await run($, 'generate', name)
  if (generated.exitCode !== 0) return generated.stderr.trim()
  const answer = afterRequest(name, await run($, 'request', name, await $.session.id()))
  // Not from the command's hook: a command run there would wait on the turn it holds.
  if (answer.exit) $.clock.after(300, () => $.command.run({ command: 'exit' }))

  return answer.text
}

// Makes `name` the default profile (claude-profile default); the text to show.
async function setDefault($: EngineInterface, name: string) {
  const set = await run($, 'default', name)
  return (set.exitCode === 0 ? set.stdout : set.stderr).trim()
}

// Opens the profile list, to switch (PICKER), to view (VIEWER) or for the default
// (DEFAULTER); whether it is drawn.
async function openPicker($: EngineInterface, id: string) {
  const list = await profiles($)
  const opened = await $.ui.open({ id, title: 'Profil Claude Code', focus: true, closeOnEscape: true, rows: list.length + 3 })

  return opened.isPlaced && list.length > 0
}

// Leaves edit mode on `name`'s view, its draft dropped (or puts it in edit mode, empty).
function setDraft($: EngineInterface, name: string, draft?: Draft) {
  return update($, drafts, all => {
    const { [name]: _, ...rest } = all
    return draft ? { ...rest, [name]: draft } : rest
  })
}

// Opens the view of profile `name` (what claude-profile show says of it), read-only or in
// edit mode; whether it is drawn.
async function openDetail($: EngineInterface, name: string, isEditing = false) {
  const shown = await run($, 'show', name)
  if (shown.exitCode !== 0) return false
  await setDraft($, name, isEditing ? {} : undefined)
  const rows = shown.stdout.trimEnd().split('\n').length + 4

  return (await $.ui.open({ id: DETAIL + name, title: `Profil ${name}`, focus: true, closeOnEscape: true, rows })).isPlaced
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'profile',
      description:
        'Choisir un profil dans une liste, relancer cette conversation dans le profil donné, voir ce qui est actif sur un profil (show), ou choisir le profil par défaut (default)',
      argumentHint: '[<profil> | show [<profil>] | create <nom> | default [<profil>] | stop | cancel]',
    })

    return next(e)
  })

  on('command.run', { command: 'profile' }, async ($, e) => {
    const args = e.args.trim()
    const create = /^create(?:\s+(\S+)(?:\s+(.*))?)?$/.exec(args)
    if (create) {
      if (!create[1]) return { text: 'usage : /profile create <nom> [description]' }
      const made = create[2] ? await run($, 'new', create[1], create[2]) : await run($, 'new', create[1])
      if (made.exitCode !== 0) return { text: made.stderr.trim() }
      await run($, 'generate', create[1])
      const isShown = await openDetail($, create[1], true)

      return { text: `Profil ${create[1]} créé (plugins du profil de référence)${isShown ? ' : choisir ses plugins dans la vue, puis v pour valider' : ''}.` }
    }
    const show = /^show(?:\s+(\S+))?$/.exec(args)
    if (show?.[1]) {
      if (await openDetail($, show[1])) return { text: `Vue du profil ${show[1]} (m : modifier ses plugins et MCP, Échap : fermer).` }
      const shown = await run($, 'show', show[1])

      return { text: (shown.exitCode === 0 ? shown.stdout : shown.stderr).trimEnd() }
    }
    if (show) {
      if (await openPicker($, VIEWER)) return { text: 'Profil à afficher (Entrée : voir, Échap : annuler).' }
      const shown = await run($, 'show')

      return { text: (shown.stdout || shown.stderr).trimEnd() }
    }
    const def = /^default(?:\s+(\S+))?$/.exec(args)
    if (def?.[1]) return { text: await setDefault($, def[1]) }
    if (def) {
      if (await openPicker($, DEFAULTER)) return { text: 'Profil par défaut (Entrée : le choisir, Échap : annuler).' }
      const now = await run($, 'default')

      return { text: `Profil par défaut : ${now.stdout.trim() || 'reference'}. /profile default <profil> pour le changer, /profile default reference pour n'en garder aucun.` }
    }
    // A background session's switch: stop it (claude stop, the loop relaunching the
    // conversation once the claude of this terminal is quit), or cancel the request left.
    if (args === 'stop') {
      if ((await run($, 'background')).exitCode !== 0) return { text: "Cette session n'est pas en arrière-plan : /exit suffit." }
      const id = await $.session.id()
      // Not from the command's hook: the session stops with it.
      $.clock.after(300, () => void $.process.run(['claude', 'stop', id.slice(0, 8)]))

      return { text: 'Arrêt de cette session : quitter ensuite le claude de ce terminal (Ctrl+C) pour basculer.' }
    }
    if (args === 'cancel') {
      await run($, 'request', '--cancel')

      return { text: 'Bascule annulée.' }
    }
    if (args) return { text: await switchTo($, args) }
    if (await openPicker($, PICKER)) return { text: 'Choix du profil (Entrée : relancer dedans, Échap : annuler).' }
    const text = await run($, 'list')

    return { text: (text.stdout || text.stderr).trimEnd() + HINT }
  })

  on('ui.render', { component: 'Pane', requestId: [PICKER, VIEWER, DEFAULTER] }, async ($, e) => {
    const elements = $.ui.resolve(e)
    const { Box, Text } = elements
    // The mobile app draws no Select yet: /profile [show] <profil> there.
    if (!('Select' in elements)) return <Text dimColor>{'Choix indisponible ici : /profile [show] <profil>.'}</Text>
    const { Select } = elements
    const list = await profiles($)
    if (list.length === 0) return <Text dimColor>Aucun profil (claude-profile list n'a rien rendu).</Text>
    const label = (p: Profile) =>
      `${p.name}${p.isCurrent ? ' (actuel)' : ''}${p.isDefault ? ' (par défaut)' : ''}${p.description ? ` — ${p.description}` : ''}`
    const pick = async (name: string) => {
      await $.ui.close({ id: e.requestId })
      if (e.requestId === VIEWER) await openDetail($, name)
      else $.ui.log(e.requestId === DEFAULTER ? await setDefault($, name) : await switchTo($, name))
    }
    const hint = {
      [PICKER]: 'Entrée : relancer la conversation dans ce profil',
      [VIEWER]: 'Entrée : voir ce profil',
      [DEFAULTER]: 'Entrée : en faire le profil par défaut (nouvelles sessions de la fonction shell claude, cl ; reference : aucun)',
    }[e.requestId]

    return (
      <Box flexDirection="column">
        <Select
          key="profile"
          label="Profil : "
          autoFocus
          options={list.map(p => ({ value: p.name, label: label(p) }))}
          value={list.find(p => (e.requestId === DEFAULTER ? p.isDefault : p.isCurrent))?.name}
          onSelect={(name: string) => void pick(name)}
        />
        <Text dimColor>
          {hint} · Échap : annuler
        </Text>
      </Box>
    )
  })

  // A profile's view: what is active on it, read-only; in edit mode (m) each plugin a button
  // that flips it in a draft, applied by v.
  on('ui.render', { component: 'Pane', requestId: /^profile-show--/ }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const name = e.requestId.slice(DETAIL.length)
    const draft = (await read($, drafts))[name]
    const shown = await run($, 'show', name)
    if (shown.exitCode !== 0) return <Text>{shown.stderr.trim()}</Text>
    const lines = parseShow(shown.stdout)
    const isCurrent = (await run($, 'current')).stdout.trim() === name
    const validate = async () => {
      for (const { action, name: item, state } of draftChanges(lines, draft ?? {})) {
        const set = await run($, action, name, item, state)
        if (set.exitCode !== 0 || set.stderr.trim()) $.ui.log(set.stderr.trim() || set.stdout.trim())
      }
      await setDraft($, name)
    }
    const relaunch = async () => {
      await $.ui.close({ id: e.requestId })
      $.ui.log(await switchTo($, name))
    }
    const box = (isOn: boolean) => (isOn ? '[x]' : '[ ]')

    return (
      <Box flexDirection="column">
        {lines.map(line => {
          if ('text' in line) return <Text>{line.text}</Text>
          const label = 'plugin' in line ? line.plugin : line.mcp
          const note = 'plugin' in line ? (line.isListed ? '' : ' (absent du profil)') : line.note ? ` ${line.note}` : ''
          if (!draft) return <Text>{`  ${box(line.isOn)} ${label}${note}`}</Text>
          const key = draftKey(line)
          const wanted = draft[key] ?? line.isOn

          return (
            <Button key={`item:${key}`} onPress={() => void setDraft($, name, toggleDraft(draft, key, line.isOn))}>
              {`  ${box(wanted)} ${label}${note}${wanted !== line.isOn ? ' *' : ''}`}
            </Button>
          )
        })}
        {draft ? (
          <Box flexDirection="row">
            <Button key="validate" hotkey="v" onPress={() => void validate()}>Valider</Button>
            <Button key="cancel" hotkey="a" onPress={() => void setDraft($, name)}>Annuler</Button>
            <Text dimColor>{'  Entrée : (dés)activer le plugin ou le MCP (* : à appliquer) · Échap : fermer sans appliquer'}</Text>
          </Box>
        ) : (
          <Box flexDirection="row">
            <Button key="edit" hotkey="m" onPress={() => void setDraft($, name, {})}>Modifier</Button>
            {!isCurrent && <Button key="switch" hotkey="b" onPress={() => void relaunch()}>Basculer dans ce profil</Button>}
            <Text dimColor>
              {isCurrent ? '  profil de cette session (relancer pour appliquer)' : ''} · Échap : fermer
            </Text>
          </Box>
        )}
      </Box>
    )
  })
}
