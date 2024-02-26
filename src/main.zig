const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
});
const Game = struct {
    const TileState = enum { Empty, Player1, Player2 };
    const PlayerId = enum(usize) { P1 = 0, P2 = 1 };

    const TileColor = blk: {
        var aux = std.EnumArray(TileState, ray.Color).initUndefined();
        aux.set(.Empty, ray.BLACK);
        aux.set(.Player1, ray.YELLOW);
        aux.set(.Player2, ray.RED);
        break :blk aux;
    };
    const board_nx = 7;
    const board_ny = 6;
    const board_pxw = tile_size * board_nx;
    const board_pxh = Options.height;
    const tile_size = Options.height / board_ny;
    const x_offset = (Options.width - board_nx * tile_size) / 2;
    const State = enum {
        Start,
        Running,
        WonP1,
        WonP2,
        Pause,
    };
    const Animation = struct {
        const gravity = 10000.0; // px / s^2
        var t: f32 = undefined; // In seconds
        var speed_y: f32 = undefined;
        var c_x: f32 = undefined;
        var c_y: f32 = undefined;
        var end_y: f32 = undefined;
        var active: bool = false;
        var col: usize = undefined;
        var row: usize = undefined;
        var ts: TileState = undefined;
        var just_ended: bool = undefined;

        fn start(_col: usize, _row: usize, start_x: f32, start_y: f32, _end_y: f32, _ts: TileState) void {
            active = true;
            t = 0.0;
            end_y = _end_y;
            c_x = start_x;
            c_y = start_y;
            ts = _ts;
            col = _col;
            row = _row;
            speed_y = 0;
            just_ended = false;
        }
        fn update(dt: f32) void {
            if (active) {
                speed_y += gravity * dt;
                c_y += speed_y * dt;
                if (c_y >= end_y) {
                    active = false;
                    just_ended = true;
                }
            }
        }
        fn draw() void {
            if (active) {
                ray.DrawCircleSector(
                    ray.Vector2{ .x = c_x, .y = c_y },
                    @as(f32, tile_size) / 2.5,
                    0,
                    360,
                    36,
                    TileColor.get(ts),
                );
            }
        }
        fn justEnded() bool {
            if (!just_ended) return false else {
                just_ended = false;
                return true;
            }
        }
    };

    var board: [board_nx * board_ny]TileState = [1]TileState{.Empty} ** (board_nx * board_ny);
    var current_player: PlayerId = undefined;
    var board_texture: ray.RenderTexture2D = undefined;
    var state: State = undefined;

    inline fn getTile(x: usize, y: usize) TileState {
        return board[board_ny * x + y];
    }
    inline fn setTile(x: usize, y: usize, val: TileState) void {
        board[board_ny * x + y] = val;
    }

    fn getFirstEmptyIndex(col: usize) ?usize {
        for (0..board_ny) |rev_y| {
            const y = board_ny - 1 - rev_y;
            if (getTile(col, y) == .Empty) {
                return y;
            }
        }
        return null;
    }

    fn checkWinner(col: usize, row: usize) bool {
        // We only check for the last placed piece
        // Check if we have 3 rows left of us
        const ct: TileState = switch (current_player) {
            .P1 => .Player1,
            .P2 => .Player2,
        };
        if (col >= 3) {
            if (getTile(col - 3, row) == ct and getTile(col - 2, row) == ct and getTile(col - 1, row) == ct and getTile(col, row) == ct) {
                return true;
            }
            // Check if we have three cols below us
            if (row >= 3) {
                if (getTile(col - 3, row - 3) == ct and getTile(col - 2, row - 2) == ct and getTile(col - 1, row - 1) == ct and getTile(col, row) == ct) {
                    return true;
                }
            }
            if (row < board_ny - 3) {
                if (getTile(col - 3, row + 3) == ct and getTile(col - 2, row + 2) == ct and getTile(col - 1, row + 1) == ct and getTile(col, row) == ct) {
                    return true;
                }
            }
        }
        if (col < board_nx - 3) {
            if (getTile(col + 3, row) == ct and getTile(col + 2, row) == ct and getTile(col + 1, row) == ct and getTile(col, row) == ct) {
                return true;
            }
            // Check if we have three cols below us
            if (row >= 3) {
                if (getTile(col + 3, row - 3) == ct and getTile(col + 2, row - 2) == ct and getTile(col + 1, row - 1) == ct and getTile(col, row) == ct) {
                    return true;
                }
            }
            if (row < board_ny - 3) {
                if (getTile(col + 3, row + 3) == ct and getTile(col + 2, row + 2) == ct and getTile(col + 1, row + 1) == ct and getTile(col, row) == ct) {
                    return true;
                }
            }
        }
        if (row >= 3) {
            if (getTile(col, row - 3) == ct and getTile(col, row - 2) == ct and getTile(col, row - 1) == ct and getTile(col, row) == ct) {
                return true;
            }
        }
        if (row < board_ny - 3) {
            if (getTile(col, row + 3) == ct and getTile(col, row + 2) == ct and getTile(col, row + 1) == ct and getTile(col, row) == ct) {
                return true;
            }
        }
        return false;
    }

    fn update(dt: f32) void {
        switch (state) {
            .Running => {
                Animation.update(dt);
                if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT) and !Animation.active) {
                    const mouse_x = ray.GetMouseX();
                    if (mouse_x >= x_offset) {
                        const column: usize = @as(usize, @intCast((mouse_x - x_offset))) / tile_size;
                        if (getFirstEmptyIndex(column)) |row| {
                            const ts: TileState = switch (current_player) {
                                .P1 => .Player1,
                                .P2 => .Player2,
                            };
                            Animation.start(
                                column,
                                row,
                                @floatFromInt((x_offset + column * tile_size + tile_size / 2)),
                                -50,
                                @floatFromInt((row * tile_size + tile_size / 2)),
                                ts,
                            );
                        }
                    }
                } else if (ray.IsKeyPressed(ray.KEY_P)) {
                    state = .Pause;
                } else if (Animation.justEnded()) {
                    setTile(Animation.col, Animation.row, Animation.ts);
                    if (checkWinner(Animation.col, Animation.row)) {
                        switch (current_player) {
                            .P1 => state = .WonP1,
                            .P2 => state = .WonP2,
                        }
                    } else {
                        current_player = switch (current_player) {
                            .P1 => .P2,
                            .P2 => .P1,
                        };
                    }
                }
            },
            .Pause => {
                if (ray.IsKeyPressed(ray.KEY_P)) {
                    state = .Running;
                }
            },
            .WonP1 => {
                if (ray.IsKeyPressed(ray.KEY_R)) {
                    state = .Running;
                    @memset(&board, .Empty);
                }
            },
            .WonP2 => {
                if (ray.IsKeyPressed(ray.KEY_R)) {
                    state = .Running;
                    @memset(&board, .Empty);
                }
            },
            else => {
                std.log.err("TODO: Uninmplemented state: {s}", .{@tagName(state)});
                std.os.exit(0xff);
            },
        }
    }

    fn draw() void {
        switch (state) {
            .Running => {
                Animation.draw();
                drawBoard();
                var buff: [20]u8 = undefined;
                const n: u32 = switch (current_player) {
                    .P1 => 1,
                    .P2 => 2,
                };
                const str = std.fmt.bufPrint(&buff, "Turno J{}\x00", .{n}) catch unreachable;
                ray.DrawText(str.ptr, 10, 10, 20, ray.RED);
            },
            .Pause => {
                Animation.draw();
                drawBoard();
                ray.DrawText("PAUSA", 10, 10, 60, colorFromHex(0xFF0000FF));
            },
            .WonP1 => {
                drawBoard();
                ray.DrawText("Ganó el jugador 1, pulsa «r» para reiniciar", 10, 10, 25, colorFromHex(0xFF0000FF));
            },
            .WonP2 => {
                drawBoard();
                ray.DrawText("Ganó el jugador 2, pulsa «r» para reiniciar", 10, 10, 25, colorFromHex(0xFF0000FF));
            },
            else => {
                std.log.err("TODO: Uninmplemented state: {s}", .{@tagName(state)});
                std.os.exit(0xff);
            },
        }
    }

    fn drawBoard() void {
        ray.DrawTexture(board_texture.texture, x_offset, 0, ray.WHITE);
        for (0..board_nx) |x| {
            const screen_x = x_offset + x * tile_size;
            for (0..board_ny) |y| {
                const ts = getTile(x, y);
                if (ts != .Empty) {
                    const screen_y = y * tile_size;
                    const center = ray.Vector2{
                        .x = @floatFromInt(screen_x + tile_size / 2),
                        .y = @floatFromInt(screen_y + tile_size / 2),
                    };
                    ray.DrawCircleSector(
                        center,
                        @as(f32, tile_size) / 2.5,
                        0,
                        360,
                        36,
                        TileColor.get(getTile(x, y)),
                    );
                }
            }
        }
    }
};

const Options = struct {
    const width = 1000;
    const height = 600;
    const title = "Z4";
};

fn colorFromHex(col: u32) ray.Color {
    // Type punning
    return ray.Color{
        .r = @intCast((col & 0xFF000000) >> 8 * 3),
        .g = @intCast((col & 0x00FF0000) >> 8 * 2),
        .b = @intCast((col & 0x0000FF00) >> 8 * 1),
        .a = @intCast((col & 0x000000FF) >> 8 * 0),
    };
}

fn createBoardTexture() ray.RenderTexture2D {
    const texture = ray.LoadRenderTexture(Game.board_pxw, Game.board_pxh);
    ray.BeginTextureMode(texture);
    ray.rlSetBlendFactors(ray.RL_ONE, ray.RL_ZERO, ray.RL_FUNC_ADD);
    ray.BeginBlendMode(ray.BLEND_CUSTOM);
    ray.ClearBackground(colorFromHex(0x0000FFFF));
    for (0..Game.board_nx) |x| {
        const screen_x = x * Game.tile_size;
        for (0..Game.board_ny) |y| {
            const screen_y = y * Game.tile_size;
            const center = ray.Vector2{
                .x = @floatFromInt(screen_x + Game.tile_size / 2),
                .y = @floatFromInt(screen_y + Game.tile_size / 2),
            };
            ray.DrawCircleSector(
                center,
                @as(f32, Game.tile_size) / 2.5,
                0,
                360,
                36,
                colorFromHex(0),
            );
        }
    }
    ray.EndBlendMode();
    ray.EndTextureMode();
    return texture;
}

pub fn main() !u8 {
    ray.InitWindow(Options.width, Options.height, Options.title);
    defer ray.CloseWindow();

    Game.board_texture = createBoardTexture();
    defer ray.UnloadTexture(Game.board_texture.texture);
    ray.SetTargetFPS(30);

    Game.current_player = .P1;
    Game.state = .Running;
    while (!ray.WindowShouldClose()) {
        const dt = ray.GetFrameTime();
        Game.update(dt);
        ray.BeginDrawing();
        ray.ClearBackground(ray.BLACK);
        // std.debug.print("{}, {}\n", .{ Game.Animation.c_x, Game.Animation.c_y });
        Game.draw();
        ray.EndDrawing();
    }
    return 0;
}
