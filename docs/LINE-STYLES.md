`Line` accepts optional `compound: LineCompound?` and `dash: LineDash?`
settings for new shape outlines and table borders. `ReadLine.compoundStyle`
and `dashStyle` expose the actual XML tokens, including unfamiliar values.
The typed cases follow Microsoft's DrawingML [compound values](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.compoundlinevalues)
and [preset dash values](https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.drawing.presetlinedashvalues).

```swift
cell.setBorder(.top, line: Line(color: .black, width: .points(3),
                                compound: .double, dash: .dash))
cell.setBorder(.top, line: Line(color: .black, compound: .single, dash: .solid))
```

For an existing table border, nil compound/dash settings retain its authored
style. Explicit `.single` and `.solid` reset those settings; a preset dash
replaces a custom dash choice. Editing retains other border attributes,
extensions, joins and end decorations. A nil line suppresses the border with
`a:noFill`; `clearBorder` restores table-style inheritance.

These APIs describe file content. Qualified double-border rendering covers
only the table renderer's independently tested subset; it does not establish
preview support for all compounds, dashes or shape outlines. Unsupported
variants continue to report fidelity issues, and strict rendering rejects them.
