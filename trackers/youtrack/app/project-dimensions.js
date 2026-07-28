const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'project_dimensions',
  description:
    'List the available values of the project\'s dimension fields (Subsystem, Type, Priority, Fix versions, Stage/State, ...). ' +
    'ALWAYS call this before asking a human to pick a subsystem or before setting one yourself: show the available values, propose the one you infer from context, and let them confirm, pick another, or deliberately add a new one. ' +
    'Never invent a near-duplicate of an existing value ("CMS-Server" vs "CMS Server"). Adding a genuinely new value is a project-settings change - propose it explicitly; it may need a project admin. ' +
    'If issueId/projectKey are omitted, uses your focused story\'s project.',
  inputSchema: {
    type: 'object',
    properties: {
      projectKey: {
        type: 'string',
        description: 'Project key (e.g. PROJ). Omit to derive from issueId or your focused story.',
      },
      issueId: {
        type: 'string',
        description: 'Any issue in the target project. Omit to use your focused story.',
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
    let project = null;
    if (ctx.arguments.projectKey) {
      try {
        project = entities.Project.findByKey(ctx.arguments.projectKey);
      } catch (e) {
        project = null;
      }
      if (!project) return { error: 'Project ' + ctx.arguments.projectKey + ' not found or not visible to you.' };
    } else {
      const r = lib.resolveIssue(ctx.arguments.issueId);
      if (r.error) return { error: r.error };
      project = r.issue.project;
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
      dimensions: { type: 'object' },
      unreadable: { type: 'array', items: { type: 'string' } },
      usage: { type: 'string' },
    },
    required: ['project', 'dimensions'],
  },
};
