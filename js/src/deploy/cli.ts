/**
 * CLI Arguments type
 */
export interface CLIArgs {
    sandbox: boolean;
    token: string;
}

/**
 * Parses command-line arguments for sandbox flag and token string
 * @returns {CLIArgs} Object containing parsed CLI arguments
 */
export function parseArgs(): CLIArgs {
    const args = process.argv.slice(2);
    const cliArgs: CLIArgs = {
        sandbox: true, // Default to true if no arguments supplied
        token: ''      // Default to empty string
    };

    if (args.length === 0) {
        return cliArgs;
    }

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--sandbox') {
            if (i + 1 < args.length && (args[i + 1] === 'true' || args[i + 1] === 'false')) {
                cliArgs.sandbox = args[i + 1] === 'true';
                i++; // Skip the next argument as we've already processed it
            } else {
                displayHelpAndExit('Missing or invalid value for --sandbox flag. Expected "true" or "false".');
            }
        } else if (args[i] === '--token') {
            if (i + 1 < args.length && args[i + 1]) {
                cliArgs.token = args[i + 1];
                i++; // Skip the next argument as we've already processed it
            } else {
                displayHelpAndExit('Missing value for --token flag. Expected a string value.');
            }
        } else {
            displayHelpAndExit(`Unrecognized argument: ${args[i]}`);
        }
    }

    return cliArgs;
}

/**
 * Displays help information and exits with error
 * @param {string} errorMsg - Error message to display
 */
function displayHelpAndExit(errorMsg: string) {
    console.error('Error: ' + errorMsg);
    console.log('\nAvailable commands:');
    console.log('  node --loader ts-node/esm src/deploy.ts                                # Run with sandbox mode (default)');
    console.log('  node --loader ts-node/esm src/deploy.ts --sandbox true                 # Run with sandbox mode enabled');
    console.log('  node --loader ts-node/esm src/deploy.ts --sandbox false                # Run with sandbox mode disabled');
    console.log('  node --loader ts-node/esm src/deploy.ts --token <token-value>          # Specify a token value');
    console.log('  node --loader ts-node/esm src/deploy.ts --sandbox false --token abc123 # Combined usage');
    process.exit(1);
}