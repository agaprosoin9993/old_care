import 'package:flutter/material.dart';

import '../../models/contact.dart';
import '../../services/api_client.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key, required this.api, required this.isAuthed});

  final ApiClient api;
  final bool isAuthed;

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool loading = false;
  List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.isAuthed) return; // 需要登录
    setState(() => loading = true);
    try {
      contacts = await widget.api.fetchContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addOrEdit({Contact? contact}) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (_) => _ContactDialog(contact: contact),
    );
    if (result == null) return;
    setState(() => loading = true);
    try {
      if (result.id == null) {
        final created = await widget.api.createContact(result);
        if (created != null) contacts.add(created);
      } else {
        final updated = await widget.api.updateContact(result);
        if (updated != null) {
          final idx = contacts.indexWhere((c) => c.id == updated.id);
          if (idx >= 0) contacts[idx] = updated;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _delete(Contact c) async {
    setState(() => loading = true);
    try {
      if (c.id != null) await widget.api.deleteContact(c.id!);
      contacts.removeWhere((x) => x.id == c.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthed) {
      return const Center(child: Text('请登录后管理家属/联系人'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('家属与紧急联系人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              FilledButton.icon(
                onPressed: loading ? null : () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (contacts.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('暂无联系人')))
          else
            ...contacts.map((c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.family_restroom),
                    title: Text(c.name),
                    subtitle: Text('${c.relation.isNotEmpty ? c.relation : '家属'} · ${c.phone}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(onPressed: () => _addOrEdit(contact: c), icon: const Icon(Icons.edit)),
                        IconButton(
                          onPressed: () => _confirmDelete(c),
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除 ${c.name} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      _delete(c);
    }
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.contact});
  final Contact? contact;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController relation;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.contact?.name ?? '');
    phone = TextEditingController(text: widget.contact?.phone ?? '');
    relation = TextEditingController(text: widget.contact?.relation ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? '新增联系人' : '编辑联系人'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: '姓名')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: '电话')),
          TextField(controller: relation, decoration: const InputDecoration(labelText: '关系')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              Contact(
                id: widget.contact?.id,
                name: name.text.trim(),
                phone: phone.text.trim(),
                relation: relation.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
