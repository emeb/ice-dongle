/*
 * cmd.c - command interpreter
 * 11-12-2022 E. Brombaugh
 * Uses parsing routines from https://github.com/FARLY7/embedded-cli
 */
#include <stdio.h>
#include <string.h>
#include "cli.h"
#include "acia.h"
#include "printf.h"

cli_t cli;

/*
 * handle HELP command
 */
static cli_status_t help_func(int argc, char **argv)
{
    cli.println("HELP function executed");
    return CLI_OK;
}

/*
 * handle BLINK command
 */
static cli_status_t blink_func(int argc, char **argv)
{
    if(argc > 0)
    {
        if(strcmp(argv[1], "-help") == 0)
        {
            cli.println("BLINK help menu");
        }
        else
        {
            return CLI_E_INVALID_ARGS;
        }
    }
    else
    {
        cli.println("BLINK function executed");
    }
    return CLI_OK;
}

/*
 * line print function
 */
void println(char *string)
{
    printf("%s\n\r", string);
}

/*
 * command table
 */
cmd_t cmd_tbl[] = {
    {
        .cmd = "help",
        .func = help_func
    },
    {
        .cmd = "blink",
        .func = blink_func
    }
};

/*
 * init the command interp
 */
void cmd_init(void)
{
    cli.println = println;
    cli.cmd_tbl = cmd_tbl;
    cli.cmd_cnt = sizeof(cmd_tbl)/sizeof(cmd_t);
    cli_init(&cli);
}

/*
 * process commands from serial I/O
 */
void cmd_proc(void)
{
	/* send char to CLI if available */
	int c=acia_getc();
	if(c != EOF)
		cli_put(&cli, c);
	
	/* process CLI */
	cli_process(&cli);
}

