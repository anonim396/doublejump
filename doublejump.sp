#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

// Server variables.
ConVar g_hMaxDoubleJumps;
ConVar g_hDoubleJumpForce;

int g_iMaxDoubleJumps;
float g_fDoubleJumpForce;

// Player variables.
bool g_bCanDoubleJump[MAXPLAYERS + 1];
int g_iDoubleJumps[MAXPLAYERS + 1] = {1, ...};

// Enums.
enum VelocityOverride
{
	VO_None = 0,
	VO_Velocity,
	VO_OnlyWhenNegative,
	VO_InvertReuseVelocity
};

public Plugin myinfo = {
	name = "Double Jump",
	author = "",
	description = "Добавляет двойной прыжок.",
	version = "1",
	url = ""
}

/*
 * Forwards.
 */
public void OnPluginStart()
{
	g_hMaxDoubleJumps = CreateConVar("ss_doublejump_max_double_jumps", "1", "Максимальное количество раз, которое игрок может подпрыгнуть в воздухе после первого прыжка..", _, true, 0.0);
	g_hMaxDoubleJumps.AddChangeHook(ConVar_OnMaxDoubleJumpsChanged);
	g_iMaxDoubleJumps = g_hMaxDoubleJumps.IntValue;

	g_hDoubleJumpForce = CreateConVar("ss_doublejump_force", "260.0", "Величина вертикального ускорения, применяемая к игроку при двойном прыжке..", _, true, 0.0);
	g_hDoubleJumpForce.AddChangeHook(ConVar_OnDoubleJumpForceChanged);
	g_fDoubleJumpForce = g_hDoubleJumpForce.FloatValue;

	AutoExecConfig();
}
public void OnClientDisconnect(int client)
{
	g_bCanDoubleJump[client] = false;
	g_iDoubleJumps[client] = 1;
}

/**
 * Изменение консольной комманды.
 */

public void ConVar_OnMaxDoubleJumpsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMaxDoubleJumps = convar.IntValue;
}

public void ConVar_OnDoubleJumpForceChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fDoubleJumpForce = convar.FloatValue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	static int s_iLastButtons[MAXPLAYERS + 1] = {0, ...};
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");

	if (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2 || GetEntityMoveType(client) == MOVETYPE_LADDER)
        return Plugin_Continue;

	if (iGroundEntity != -1)
		g_iDoubleJumps[client] = 1;
	
	if ((buttons & IN_JUMP) == IN_JUMP && !(s_iLastButtons[client] & IN_JUMP) && iGroundEntity == -1)
	{
		/*
		// Первоначально этот блок описывался как «идеальный двойной прыжок».
		float fVelocity[3];
		//GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
					
		if (fVelocity[2] < 0.0)
		*/
		DoubleJump(client);
	}

	s_iLastButtons[client] = buttons;
	
	return Plugin_Continue;
}

void DoubleJump(int client)
{
	if (1 <= g_iDoubleJumps[client] <= g_iMaxDoubleJumps)
	{
		g_iDoubleJumps[client]++;

		float fAngles[3] = {-90.0, 0.0, 0.0};
		VelocityOverride hVelocityOverride[3] = {VO_None, VO_None, VO_Velocity};
		PushClient(client, fAngles, g_fDoubleJumpForce, hVelocityOverride);
	}
}

void PushClient(int client, float angles[3], float power, VelocityOverride override[3]={VO_None})
{
	// Спасибо DarthNinja и Javalia за это.
	float fNewVelocity[3];
	float fForwardVector[3];
	
	GetAngleVectors(angles, fForwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fForwardVector, fForwardVector);
	ScaleVector(fForwardVector, power);

	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fNewVelocity);
	
	for (int i = 0; i < 3; i++)
	{
		switch (override[i])
		{
			case VO_Velocity:
			{
				fNewVelocity[i] = 0.0;
			}
			case VO_OnlyWhenNegative:
			{				
				if (fNewVelocity[i] < 0.0)
					fNewVelocity[i] = 0.0;
			}
			case VO_InvertReuseVelocity:
			{				
				if(fNewVelocity[i] < 0.0)
					fNewVelocity[i] *= -1.0;
			}
		}
		
		fNewVelocity[i] += fForwardVector[i];
	}
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fNewVelocity);
}