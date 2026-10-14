// A profile's draft while its view is in edit mode: plugin → wanted state, for the
// plugins changed since entering it.
export type Draft = Record<string, boolean>

declare module 'claude-code' {
  interface PluginState {
    // The drafts of the views in edit mode, by profile; a view absent here is read-only.
    profiles: { drafts: Record<string, Draft> }
  }
}
