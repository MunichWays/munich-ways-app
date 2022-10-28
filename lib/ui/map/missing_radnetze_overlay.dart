import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

class MissingRadnetzeCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const MissingRadnetzeCard(
      {Key? key, required this.loading, required this.onPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Keine Radnetze gefunden",
                  style: Theme.of(context).textTheme.headline6,
                ),
                SizedBox(
                  height: 16,
                ),
                Text(
                  "Beim Laden der Radlnetze ist ein Fehler aufgetreteten. Bitte überprüfe Deine Internetverbindung und versuche es erneut.",
                  style: Theme.of(context).textTheme.subtitle1,
                ),
                SizedBox(
                  height: 16,
                ),
                this.loading
                    ? CircularProgressIndicator()
                    : TextButton.icon(
                        onPressed: onPressed,
                        icon: Icon(
                          Icons.refresh,
                          color: AppColors.munichWaysBlue,
                        ),
                        label: Text(
                          "Radlnetze laden",
                          style: Theme.of(context).textTheme.button!.copyWith(
                              fontSize: 18, color: AppColors.munichWaysBlue),
                        ),
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
