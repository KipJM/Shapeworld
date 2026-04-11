using System;
using Godot;


public partial class Player : FPSController3D
{
    [Export] public string InputBackActionName { get; set; } = "move_backward";
    [Export] public string InputForwardActionName { get; set; } = "move_forward";
    [Export] public string InputLeftActionName { get; set; } = "move_left";
    [Export] public string InputRightActionName { get; set; } = "move_right";
    [Export] public string InputSprintActionName { get; set; } = "move_sprint";
    [Export] public string InputJumpActionName { get; set; } = "move_jump";
    [Export] public string InputCrouchActionName { get; set; } = "move_crouch";
    [Export] public string InputFlyModeActionName { get; set; } = "move_fly_mode";
    
    [Export] public string ViewBackActionName { get; set; } = "view_backward";
    [Export] public string ViewForwardActionName { get; set; } = "view_forward";
    [Export] public string ViewLeftActionName { get; set; } = "view_left";
    [Export] public string ViewRightActionName { get; set; } = "view_right";
    
    [Export] public float ControllerSensitivity { get; set; } = 5f;
    
    [Export] public Godot.Environment UnderwaterEnv { get; set; }

    public override void _Ready()
    {
        Input.MouseMode = Input.MouseModeEnum.Captured;
        Setup();
        Emerged += OnControllerEmerged;
        Submerged += OnControllerSubemerged;
    }

    public override void _PhysicsProcess(double delta)
    {
        bool IsValidInput = Input.MouseMode == Input.MouseModeEnum.Captured;
        
        if (IsValidInput)
        {
            if (Input.IsActionJustPressed(InputFlyModeActionName))
            {
                FlyAbility.SetActive(!FlyAbility.IsActived());
            }

            Vector2 InputAxis = Input.GetVector(InputBackActionName, InputForwardActionName, InputLeftActionName, InputRightActionName);
            bool InputJump = Input.IsActionJustPressed(InputJumpActionName);
            bool InputCrouch = Input.IsActionPressed(InputCrouchActionName);
            bool InputSprint = Input.IsActionPressed(InputSprintActionName);
            bool InputSwimDown = Input.IsActionPressed(InputCrouchActionName);
            bool InputSwimUp = Input.IsActionPressed(InputJumpActionName);

            Move((float)delta, InputAxis, InputJump, InputCrouch, InputSprint, InputSwimDown, InputSwimUp);
        }
        else
        {
            Move((float)delta);
        }
    }

    public override void _Process(double delta)
    {
        base._Process(delta);
        RotateHead(Input.GetVector(ViewLeftActionName, ViewRightActionName, ViewForwardActionName, ViewBackActionName) * (float)delta * ControllerSensitivity);
    }

    public override void _Input(InputEvent @event)
    {
        // Mouse look (only if the mouse is captured).
        if (@event is InputEventMouseMotion eventMouseMotion && Input.MouseMode == Input.MouseModeEnum.Captured)
        {
            RotateHead(eventMouseMotion.Relative);
        }
    }

    private void OnControllerEmerged()
    {
        camera.Environment = null;
    }

    private void OnControllerSubemerged()
    {
        camera.Environment = UnderwaterEnv;
    }
}
