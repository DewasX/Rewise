import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  // 1. Initialize Supabase Admin Client
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  console.log('Running nightly retention recalculation...');

  // 2. Fetch all active users
  const { data: users, error: userError } = await supabase.from('users').select('user_id, daily_available_minutes');
  
  if (userError || !users) {
    return new Response(JSON.stringify({ error: userError }), { status: 500 });
  }

  for (const user of users) {
    // 3. Update memory scores and retentions for all topics
    // Example: RPC call to complex postgres logic or batch updating via Deno
    const { data: topics, error: topicsErr } = await supabase
      .from('topics')
      .select('*')
      .eq('user_id', user.user_id);

    if (topicsErr || !topics) continue;

    const updates = topics.map(t => {
      // 4. Recalulate math
      const daysSinceReview = (Date.now() - new Date(t.last_reviewed_at).getTime()) / (1000 * 3600 * 24);
      // Retention = e^(-t / Stability)
      const retention = Math.exp(-daysSinceReview / (t.stability_value || 1.0));
      const memoryScore = retention * 100;
      
      let status = 'Urgent';
      if (memoryScore >= 80) status = 'Strong';
      else if (memoryScore >= 60) status = 'Stable';
      else if (memoryScore >= 40) status = 'Fading';

      return {
        ...t,
        retention,
        memory_score: memoryScore,
        status,
        overdue_days: Math.max(0, daysSinceReview - (t.interval_days || 1))
      };
    });

    // 5. Upsert batch updates
    await supabase.from('topics').upsert(updates);

    // 6. Generate the Study Plan based on priority (100 - Retention + Overdue Days * 5)
    // Priority logic can be enforced here by limiting to daily_available_minutes
  }

  return new Response("Nightly sync completed!", { status: 200 })
})
