import { expect, test } from 'claude-code/testing'

import { afterRequest, draftChanges, manual, parseList, parseShow, toggleDraft } from '../hooks/switch'

const run = (exitCode: number, stderr = '') => ({ exitCode, stdout: '', stderr })

test('a request the loop took: exit, then relaunch', () => {
  expect(afterRequest('perso', run(0))).toEqual({ exit: true, text: 'Bascule vers le profil perso : la session se relance…' })
})

test('a session outside the loop: no exit, the manual relaunch', () => {
  expect(afterRequest('perso', run(3, 'hors boucle'))).toEqual({ exit: false, text: manual('perso') })
  expect(manual('perso')).toContain('claude-profile switch perso --continue')
})

test('an error: no exit, its message', () => {
  expect(afterRequest('x', run(2, 'profil inconnu : x\n'))).toEqual({ exit: false, text: 'profil inconnu : x' })
  expect(afterRequest('x', run(1))).toEqual({ exit: false, text: 'claude-profile request a échoué (code 1)' })
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

test('a draft holds only the plugins changed: flipped back, dropped', () => {
  const once = toggleDraft({}, 'a@m', true)
  expect(once).toEqual({ 'a@m': false })
  expect(toggleDraft(once, 'a@m', true)).toEqual({})
  expect(toggleDraft(once, 'c@m', false)).toEqual({ 'a@m': false, 'c@m': true })
})

test('a draft applied: one claude-profile plugin call per real change', () => {
  const lines = parseShow('plugins :\n  + a@m\n  - b@m (désactivé)\n  ? c@m (installé, absent du profil : inactif)\n')
  expect(draftChanges(lines, { 'a@m': false, 'b@m': false, 'c@m': true, 'x@m': true })).toEqual([
    { plugin: 'a@m', state: 'off' },
    { plugin: 'c@m', state: 'on' },
  ])
})
