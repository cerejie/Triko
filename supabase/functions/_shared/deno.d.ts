// Minimal Deno globals so `tsc -p supabase/functions` can type-check without a Deno install.
// The Edge Runtime provides the real implementations.
declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
  export function serve(handler: (request: Request) => Response | Promise<Response>): unknown;
}
