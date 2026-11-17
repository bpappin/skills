const entities = require('@jetbrains/youtrack-scripting-api/entities');
const args = require('./args');

exports.aiTool = {
  name: 'project_dimensions',
  description:
    'List the available values of the project\'s dimension fields (Subsystem, Type, Priority, Fix versions, Stage/State, ...). ' +
    'ALWAYS call this before asking a human to pick a subsystem or before setting one yourself: show the available values, propose the one you infer from context, and let them confirm, pick another, or deliberately add a new one. ' +
    'Never invent a near-duplicate of an existing value ("CMS-Server" vs "CMS Server"). Adding a genuinely new value is a project-settings change - propose it explicitly; it may need a project admin. ' +
    'Name the project every time: projectKey, or the issueId of any issue in it. It is never taken from your focused story - focus is one value per account, so it can point at another project - and the result says which project it answered for: check that it is the one you asked about.',
  inputSchema: {
    type: 'object',
    properties: {
      projectKey: {
        type: 'string',
        description: 'Project key (e.g. PROJ). Give this or issueId.',
      },
      project: {
        type: 'string',
        description: 'Another name for projectKey, accepted because it is the one callers reach for. Give one of the two.',
      },
      issueId: {
        type: 'string',
        description: 'Any issue in the target project (e.g. PROJ-123), when you have a story and not its project key.',
      },
    },
  },
  annotations: {
    title: 'List project dimension values',
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const bad = args.refuseUnknown(ctx.arguments, exports.aiTool.inputSchema);
    if (bad) return bad;

    const a = ctx.arguments || {};
    if (a.projectKey && a.project && a.projectKey !== a.project) {
      return { error: 'projectKey (' + a.projectKey + ') and project (' + a.project + ') name different projects. Give one.' };
    }
    const key = a.projectKey || a.project || null;

    // The project is never taken from focus. Focus is one value on the
    // account, shared by every agent using it, so in a tracker with several
    // projects it points wherever the last one left it - and another
    // project's values, returned without complaint, get proposed as real.
    if (!key && !a.issueId) {
      return {
        error: 'Name the project: pass projectKey (e.g. PROJ), or issueId for any issue in it. ' +
          'This tool does not take the project from your focused story, which may be in another project.',
      };
    }

    let project = null;
    let resolvedFrom = null;
    if (key) {
      try {
        project = entities.Project.findByKey(key);
      } catch (e) {
        project = null;
      }
      if (!project) return { error: 'Project ' + key + ' not found or not visible to you.' };
      resolvedFrom = 'projectKey';
    }
    if (a.issueId) {
      const issue = entities.Issue.findById(a.issueId);
      if (!issue) return { error: 'Issue ' + a.issueId + ' not found or not visible to you.' };
      if (project && issue.project.key !== project.key) {
        return { error: a.issueId + ' is in project ' + issue.project.key + ', not ' + project.key + '. Give one or the other.' };
      }
      if (!project) {
        project = issue.project;
        resolvedFrom = 'issueId';
      }
    }

    const dimensions = {};
    const unreadable = [];
    try {
      project.fields.forEach((f) => {
        let name = null;
        try { name = f.name; } catch (e) { return; }
        if (!name) return;
        const vals = [];
        try {
          if (f.values && typeof f.values.forEach === 'function') {
            f.values.forEach((v) => {
              if (v && v.name !== undefined) vals.push(v.name);
            });
          }
        } catch (e) {
          unreadable.push(name);
          return;
        }
        if (vals.length) dimensions[name] = vals;
      });
    } catch (e) {
      return {
        error: 'Could not enumerate project fields (' + e + '). Fall back to sampling: ' +
          'search recent issues and collect the distinct values in use.',
      };
    }

    return {
      project: project.key,
      resolvedFrom: resolvedFrom,
      dimensions: dimensions,
      unreadable: unreadable,
      usage:
        'Show these values when asking a human to classify work. Propose your best inference; ' +
        'confirm before setting. A value not listed here does not exist yet - adding one is a ' +
        'deliberate decision (check for near-duplicates first) and may need a project admin.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      project: { type: 'string' },
      resolvedFrom: { type: 'string' },
      dimensions: { type: 'object' },
      unreadable: { type: 'array', items: { type: 'string' } },
      usage: { type: 'string' },
    },
    required: ['project', 'dimensions'],
  },
};
