import { expect, test } from 'claude-code/testing'

import { afterRequest, draftChanges, draftKey, manual, parseList, parseShow, toggleDraft } from '../hooks/switch'

const run = (exitCode: number, stderr = '') => ({ exitCode, stdout: '', stderr })

test('a request the loop took: exit, then relaunch', () => {
  expect(afterRequest('perso', run(0))).toEqual({ exit: true, isBackground: false, text: 'Bascule vers le profil perso : la session se relance…' })
})

test('a session outside the loop: no exit, the manual relaunch', () => {
  expect(afterRequest('perso', run(3, 'hors boucle'))).toEqual({ exit: false, isBackground: false, text: manual('perso') })
  expect(manual('perso')).toContain('claude-profile switch perso --continue')
})

test('a background session: request left, no exit, the session to stop first', () => {
  const text = "Session d'arrière-plan : /exit la détache sans la quitter. Bascule vers perso en attente : …"
  expect(afterRequest('perso', run(4, `${text}\n`))).toEqual({ exit: false, isBackground: true, text })
})

test('an error: no exit, its message', () => {
  expect(afterRequest('x', run(2, 'profil inconnu : x\n'))).toEqual({ exit: false, isBackground: false, text: 'profil inconnu : x' })
  expect(afterRequest('x', run(1))).toEqual({ exit: false, isBackground: false, text: 'claude-profile request a échoué (code 1)' })
})

test('claude-profile list parsed: name, description, current', () => {
  const out = '  basic            Sans pr-comments [généré]\n* vidal            Config complète [généré, par défaut]\n  vide              [non généré]\n'
  expect(parseList(out)).toEqual([
    { name: 'basic', description: 'Sans pr-comments', isCurrent: false, isDefault: false },
    { name: 'vidal', description: 'Config complète', isCurrent: true, isDefault: true },
    { name: 'vide', description: '', isCurrent: false, isDefault: false },
  ])
})

test('claude-profile show parsed: plugins on, off, unlisted; other lines as text', () => {
  const out = 'profil : p [généré]\nplugins :\n  + a@m\n  - b@m (désactivé)\n  ? c@m (installé, absent du profil : inactif)\nmodèle : opus\n'
  expect(parseShow(out)).toEqual([
    { text: 'profil : p [généré]' },
    { text: 'plugins :' },
    { plugin: 'a@m', isOn: true, isListed: true },
    { plugin: 'b@m', isOn: false, isListed: true },
    { plugin: 'c@m', isOn: false, isListed: false },
    { text: 'modèle : opus' },
  ])
})

test('claude-profile list with the reference: default when none is set', () => {
  const out = '* reference        Profil de référence (~/.claude/settings.json) [référence, par défaut]\n  basic            Sans pr-comments [généré]\n'
  expect(parseList(out)).toEqual([
    { name: 'reference', description: 'Profil de référence (~/.claude/settings.json)', isCurrent: true, isDefault: true },
    { name: 'basic', description: 'Sans pr-comments', isCurrent: false, isDefault: false },
  ])
})

test('claude-profile show parsed: the reference state of a plugin left out of its name', () => {
  const out = 'plugins :\n  - a@m (désactivé) (référence : activé)\n  ? c@m (installé, absent du profil : inactif) (référence : activé)\nplugins différents du profil de référence : a@m, c@m\n'
  expect(parseShow(out)).toEqual([
    { text: 'plugins :' },
    { plugin: 'a@m', isOn: false, isListed: true },
    { plugin: 'c@m', isOn: false, isListed: false },
    { text: 'plugins différents du profil de référence : a@m, c@m' },
  ])
})

test('a draft holds only the plugins changed: flipped back, dropped', () => {
  const once = toggleDraft({}, 'a@m', true)
  expect(once).toEqual({ 'a@m': false })
  expect(toggleDraft(once, 'a@m', true)).toEqual({})
  expect(toggleDraft(once, 'c@m', false)).toEqual({ 'a@m': false, 'c@m': true })
})

test('a draft applied: one claude-profile plugin call per real change', () => {
  const lines = parseShow('plugins :\n  + a@m\n  - b@m (désactivé)\n  ? c@m (installé, absent du profil : inactif)\n')
  expect(draftChanges(lines, { 'a@m': false, 'b@m': false, 'c@m': true, 'x@m': true })).toEqual([
    { action: 'plugin', name: 'a@m', state: 'off' },
    { action: 'plugin', name: 'c@m', state: 'on' },
  ])
})

const MCP_SHOW =
  'plugins :\n  + a@m\nMCP :\n  + claude.ai (tous les connecteurs)\n  - claude.ai Slack (coupé) (référence : actif)\n' +
  '  + plugin:intellij:intellij\n  - https://x.example/* (coupé)\nmodèle : opus\n'

test('claude-profile show parsed: MCP servers, names with spaces, notes apart', () => {
  expect(parseShow(MCP_SHOW)).toEqual([
    { text: 'plugins :' },
    { plugin: 'a@m', isOn: true, isListed: true },
    { text: 'MCP :' },
    { mcp: 'claude.ai', isOn: true, note: '(tous les connecteurs)' },
    { mcp: 'claude.ai Slack', isOn: false, note: '(coupé) (référence : actif)' },
    { mcp: 'plugin:intellij:intellij', isOn: true, note: '' },
    { mcp: 'https://x.example/*', isOn: false, note: '(coupé)' },
    { text: 'modèle : opus' },
  ])
})

test('a draft mixing plugins and MCP: mcp: keys, one plugin or mcp call per change', () => {
  const lines = parseShow(MCP_SHOW)
  const key = draftKey({ mcp: 'claude.ai Slack' })
  expect(key).toBe('mcp:claude.ai Slack')
  let draft = toggleDraft({}, key, false)
  draft = toggleDraft(draft, 'mcp:plugin:intellij:intellij', true)
  draft = toggleDraft(draft, 'a@m', true)
  expect(draftChanges(lines, draft)).toEqual([
    { action: 'plugin', name: 'a@m', state: 'off' },
    { action: 'mcp', name: 'claude.ai Slack', state: 'on' },
    { action: 'mcp', name: 'plugin:intellij:intellij', state: 'off' },
  ])
})
