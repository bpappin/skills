const lib = require('./story-lib');

exports.aiTool = {
  name: 'log_work',
  description:
    'Record time spent on a story as a YouTrack work item. ' +
    'ONLY log a number a human has approved: propose the duration first ("Log ~2h on PROJ-123?") and call this after they confirm or correct it. Never log time silently. ' +
    'Sessions are the unit - one entry per working session, rounded to the nearest 15 minutes. ' +
    'If issueId is omitted, uses your focused story (story_set_focus).',
  inputSchema: {
    type: 'object',
    properties: {
      minutes: {
        type: 'integer',
        description: 'Approved duration in minutes (e.g. 90 for 1.5h). Must be positive.',
      },
      comment: {
        type: 'string',
        description: 'Optional short note on what the time covered.',
      },
      issueId: {
        type: 'string',
        description: 'Issue ID (e.g. PROJ-123). Omit to use your focused story.',
      },
    },
    required: ['minutes'],
  },
  annotations: {
    title: 'Log time spent on a story',
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const minutes = ctx.arguments.minutes;
    if (!minutes || minutes <= 0) {
      return { error: 'minutes must be a positive integer (e.g. 90 for 1.5h).' };
    }
    if (minutes > 16 * 60) {
      return {
        error:
          'Refusing to log ' + minutes + ' minutes in one entry - that exceeds 16h and is ' +
          'probably an unclosed session rather than real effort. Ask the human what the ' +
          'session actually took and log that.',
      };
    }

    const ro = lib.readOnlyRefusal(ctx, {
      action: 'log_work',
      minutes: minutes,
      comment: ctx.arguments.comment || null,
      issueId: ctx.arguments.issueId || null,
    });
    if (ro) return ro;

    const r = lib.resolveIssue(ctx.arguments.issueId);
    if (r.error) return { error: r.error };
    const issue = r.issue;

    const u = lib.currentUser();
    if (u.error) return { error: u.error };

    try {
      issue.addWorkItem({
        description: ctx.arguments.comment || 'Work session',
        date: Date.now(),
        author: u.user,
        duration: minutes,
      });
    } catch (e) {
      return {
        error:
          'Could not add a work item to ' + issue.id + '. Time tracking is probably not ' +
          'enabled for project ' + issue.project.key + ' - enable it in Project Settings > ' +
          'Time Tracking (or re-run the story-tools installer), then retry. (' + e + ')',
      };
    }

    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    const pretty = (h ? h + 'h' : '') + (m ? (h ? ' ' : '') + m + 'm' : h ? '' : '0m');
    return {
      issueId: issue.id,
      minutes: minutes,
      logged: pretty,
      message: 'Logged ' + pretty + ' on ' + issue.id + '.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      issueId: { type: 'string' },
      minutes: { type: 'integer' },
      logged: { type: 'string' },
      message: { type: 'string' },
    },
    required: ['issueId', 'minutes'],
  },
};
