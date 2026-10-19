// ildump <assembly.dll>            one line per method: "Type::Method/arity n=<instructions> h=<hash>"
// ildump <assembly.dll> <filter>   full IL of every method whose name line contains <filter>
//
// File hashes of two builds never match (MVID, timestamps, ILRepack GUIDs), so builds are compared
// on what the methods actually do. tools/il-diff.sh wraps this for two DLLs.
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Mono.Cecil;
using Mono.Cecil.Cil;

var asm = AssemblyDefinition.ReadAssembly(args[0]);
string filter = args.Length > 1 ? args[1] : null;

// ILRepack prefixes internalized compiler attributes with a per-build GUID.
string Norm(string s) => Regex.Replace(s ?? "", @"<[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}>", "<G>");

string Operand(Instruction i) => i.Operand switch
{
	string s => " \"" + Norm(s) + "\"",
	MethodReference m => " " + Norm(m.FullName),
	FieldReference f => " " + Norm(f.FullName),
	TypeReference t => " " + Norm(t.FullName),
	Instruction target => $" -> {target.Offset:x4}",
	null => "",
	var o => " " + o,
};

void Walk(TypeDefinition type, string prefix)
{
	string typeName = Norm(prefix + type.Name);
	foreach (MethodDefinition m in type.Methods.Where(m => m.HasBody).OrderBy(m => m.Name).ThenBy(m => m.Parameters.Count))
	{
		string name = $"{typeName}::{m.Name}/{m.Parameters.Count}";
		// Branch targets are left out of the hash: their offsets shift whenever an earlier method changes size.
		string ops = string.Join(";", m.Body.Instructions.Select(i => i.OpCode.Name + (i.Operand is Instruction or Instruction[] ? "" : Operand(i))));
		if (filter is null)
		{
			string hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(ops)))[..12];
			Console.WriteLine($"{name} n={m.Body.Instructions.Count} h={hash}");
		}
		else if (name.Contains(filter))
		{
			Console.WriteLine($"== {name}");
			foreach (Instruction i in m.Body.Instructions)
			{
				Console.WriteLine($"  {i.Offset:x4}: {i.OpCode.Name}{Operand(i)}");
			}
		}
	}
	foreach (TypeDefinition nested in type.NestedTypes.OrderBy(n => n.Name))
	{
		Walk(nested, prefix + type.Name + "/");
	}
}

foreach (TypeDefinition type in asm.MainModule.Types.OrderBy(t => Norm(t.FullName)))
{
	Walk(type, type.Namespace is { Length: > 0 } ns ? ns + "." : "");
}
