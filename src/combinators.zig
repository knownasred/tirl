// fn either(
//     p: *Parser,
//     comptime branches: anytype, // tuple of parser functions
// ) !@TypeOf(branches[0](p)) {
//     const cp = p.checkpoint();

//     inline for (branches, 0..) |branch, i| {
//         if (branch(p)) |result| {
//             return result;
//         } else |err| {
//             // Last branch: propagate the error
//             if (i == branches.len - 1) return err;
//             // Otherwise: rewind and try next
//             p.restore(cp);
//         }
//     }
//     unreachable;
