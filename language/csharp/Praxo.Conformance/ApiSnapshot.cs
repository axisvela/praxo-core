using System.Reflection;
using System.Text;
using Praxo.Core;

namespace Praxo.Conformance;

internal static class ApiSnapshot
{
    public static string Dump()
    {
        var builder = new StringBuilder();
        var assembly = typeof(Agent).Assembly;
        foreach (var type in assembly.GetExportedTypes().OrderBy(type => type.FullName, StringComparer.Ordinal))
        {
            builder.Append("### ").AppendLine(type.FullName);
            var members = new List<string>();
            const BindingFlags flags = BindingFlags.Public
                | BindingFlags.Instance
                | BindingFlags.Static
                | BindingFlags.DeclaredOnly;
            foreach (var constructor in type.GetConstructors(flags))
            {
                members.Add($"{type.Name}({Parameters(constructor)})");
            }
            foreach (var method in type.GetMethods(flags))
            {
                if (method.IsSpecialName)
                {
                    continue;
                }
                members.Add($"{TypeName(method.ReturnType)} {method.Name}({Parameters(method)})");
            }
            foreach (var property in type.GetProperties(flags))
            {
                var accessors = new List<string>();
                if (property.GetMethod?.IsPublic == true)
                {
                    accessors.Add("get");
                }
                if (property.SetMethod?.IsPublic == true)
                {
                    accessors.Add("set");
                }
                if (accessors.Count > 0)
                {
                    members.Add($"{TypeName(property.PropertyType)} {property.Name} {{ {string.Join("; ", accessors)}; }}");
                }
            }
            foreach (var field in type.GetFields(flags))
            {
                members.Add($"{TypeName(field.FieldType)} {field.Name}");
            }
            foreach (var member in members.OrderBy(member => member, StringComparer.Ordinal))
            {
                builder.Append(member).AppendLine();
            }
        }
        return builder.ToString();
    }

    private static string Parameters(MethodBase method)
        => string.Join(", ", method.GetParameters()
            .Select(parameter => $"{TypeName(parameter.ParameterType)} {parameter.Name}"));

    private static string TypeName(Type type)
        => type.IsGenericType && type.GetGenericTypeDefinition() == typeof(Nullable<>)
            ? TypeName(type.GetGenericArguments()[0]) + "?"
            : type.ToString() ?? "";
}
