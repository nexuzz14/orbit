import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getPushConfigStatus } from '@/lib/push-server';

async function resolveOptionalWebDeviceCount(): Promise<number | null> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) return null;

    const { count } = await supabase
      .from('user_devices')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('platform', 'web');
    return count ?? 0;
  } catch {
    return null;
  }
}

export async function GET() {
  const status = getPushConfigStatus();
  const deviceCount = await Promise.race<number | null>([
    resolveOptionalWebDeviceCount(),
    new Promise((resolve) => setTimeout(() => resolve(null), 1200)),
  ]);

  return NextResponse.json({
    configured: status.configured,
    status: status.status,
    publicKey: status.publicKey,
    missingVars: status.missingVars,
    instructions: status.instructions,
    deviceCount,
  });
}
